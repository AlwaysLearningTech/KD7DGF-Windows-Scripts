<#
.SYNOPSIS
    Helper functions for EmComm configuration automation
    
.DESCRIPTION
    Provides COM port auto-detection, GPS locator calculation, and secrets management
    
.NOTES
    Import with: Import-Module .\Modules\EmComm-ConfigHelper.psm1
#>

# Auto-detect available COM ports with device descriptions
function Get-AvailableComPorts {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Enumerating COM ports..."
    
    try {
        $ports = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop | 
            Where-Object { $_.Caption -match '\(COM\d+\)' } |
            ForEach-Object {
                if ($_.Caption -match '\((COM\d+)\)') {
                    [PSCustomObject]@{
                        Port = $matches[1]
                        Description = $_.Caption
                        DeviceID = $_.DeviceID
                        Status = $_.Status
                    }
                }
            } | Sort-Object Port
        
        Write-Verbose "Found $($ports.Count) COM ports"
        return $ports
    }
    catch {
        Write-Warning "Failed to enumerate COM ports: $_"
        return @()
    }
}

# Detect likely radio COM port (looks for USB serial adapters)
function Find-RadioComPort {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Searching for radio COM port..."
    
    $ports = Get-AvailableComPorts
    
    if ($ports.Count -eq 0) {
        Write-Warning "No COM ports detected"
        return "COM3"  # Fallback default
    }
    
    # Look for common radio interface patterns (in priority order)
    $radioKeywords = @(
        'USB Serial',
        'FTDI',
        'Prolific',
        'CH340',
        'CP210',
        'Digirig',
        'SignaLink',
        'Silicon Labs',
        'USB-SERIAL'
    )
    
    foreach ($keyword in $radioKeywords) {
        $match = $ports | Where-Object { $_.Description -match $keyword } | Select-Object -First 1
        if ($match) {
            Write-Verbose "Found radio port: $($match.Port) - $($match.Description)"
            return $match.Port
        }
    }
    
    # Fallback to first available COM port
    Write-Verbose "No radio-specific port found, using first available: $($ports[0].Port)"
    return $ports[0].Port
}

# Get GPS coordinates from Windows Location API
function Get-GPSLocation {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 10
    )
    
    Write-Verbose "Attempting to get GPS location (timeout: ${TimeoutSeconds}s)..."
    
    try {
        # Enable Location Services if disabled (requires admin)
        Write-Verbose "Checking Windows Location Services status..."
        $locSvcStatus = Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue
        
        if ($locSvcStatus -and $locSvcStatus.Status -ne 'Running') {
            Write-Host "Enabling Windows Location Services..." -ForegroundColor Yellow
            try {
                Set-Service -Name "lfsvc" -StartupType Automatic -ErrorAction Stop
                Start-Service -Name "lfsvc" -ErrorAction Stop
                Write-Host "Location Services enabled successfully" -ForegroundColor Green
                Start-Sleep -Seconds 2  # Give service time to initialize
            }
            catch {
                Write-Warning "Could not enable Location Services (may need admin rights): $_"
                Write-Warning "Manually enable: Settings > Privacy & Security > Location > On"
            }
        }
        
        # Load required assembly
        Add-Type -AssemblyName System.Device -ErrorAction Stop
        
        $watcher = New-Object System.Device.Location.GeoCoordinateWatcher
        $watcher.Start()
        
        # Wait for location with timeout
        $timeout = [DateTime]::Now.AddSeconds($TimeoutSeconds)
        while ($watcher.Status -ne 'Ready' -and [DateTime]::Now -lt $timeout) {
            Start-Sleep -Milliseconds 100
        }
        
        if ($watcher.Status -eq 'Ready' -and -not $watcher.Position.Location.IsUnknown) {
            $location = $watcher.Position.Location
            
            Write-Verbose "GPS location acquired: $($location.Latitude), $($location.Longitude)"
            
            return @{
                Latitude = [math]::Round($location.Latitude, 6)
                Longitude = [math]::Round($location.Longitude, 6)
                Altitude = if ($location.Altitude -ne [double]::NaN) { [math]::Round($location.Altitude, 1) } else { $null }
                Accuracy = if ($location.HorizontalAccuracy -ne [double]::NaN) { [math]::Round($location.HorizontalAccuracy, 1) } else { $null }
            }
        }
        else {
            Write-Warning "GPS location not available (timeout or no signal)"
            Write-Warning "Ensure Windows Location Services are enabled and you have GPS/WiFi positioning"
            return $null
        }
    }
    catch {
        Write-Warning "GPS location failed: $_"
        Write-Warning "Enable Location Services: Settings > Privacy & Security > Location"
        return $null
    }
    finally {
        if ($watcher) { 
            $watcher.Stop()
            $watcher.Dispose() 
        }
    }
}

# Convert coordinates to Maidenhead locator
function ConvertTo-MaidenheadLocator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(-90, 90)]
        [double]$Latitude,
        
        [Parameter(Mandatory)]
        [ValidateRange(-180, 180)]
        [double]$Longitude,
        
        [ValidateSet(4, 6, 8)]
        [int]$Precision = 6
    )
    
    Write-Verbose "Converting coordinates to Maidenhead locator (precision: $Precision)"
    
    # Adjust coordinates to Maidenhead system
    $adjLon = $Longitude + 180
    $adjLat = $Latitude + 90
    
    # Field (18° longitude × 10° latitude)
    $field = [char](65 + [math]::Floor($adjLon / 20)) + [char](65 + [math]::Floor($adjLat / 10))
    
    # Square (2° longitude × 1° latitude)
    $square = [string]([math]::Floor(($adjLon % 20) / 2)) + [string]([math]::Floor($adjLat % 10))
    
    $locator = $field + $square
    
    if ($Precision -ge 6) {
        # Subsquare (5' longitude × 2.5' latitude)
        $subsquare = [char](97 + [math]::Floor((($adjLon % 2) * 12))) + 
                     [char](97 + [math]::Floor((($adjLat % 1) * 24)))
        $locator += $subsquare
    }
    
    if ($Precision -eq 8) {
        # Extended square
        $extsquare = [string]([math]::Floor((($adjLon % 2) * 120) % 10)) +
                     [string]([math]::Floor((($adjLat % 1) * 240) % 10))
        $locator += $extsquare
    }
    
    Write-Verbose "Maidenhead locator: $locator"
    return $locator
}

# Load secrets from separate file (gitignored)
function Get-EmCommSecrets {
    <#
    .SYNOPSIS
        DEPRECATED - Secrets are now in main config file
    .DESCRIPTION
        This function is no longer needed. All secrets (license keys, passwords)
        are stored directly in EmComm-Config.json which is gitignored.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$SecretsFile
    )
    
    Write-Warning "Get-EmCommSecrets is deprecated - secrets are now in EmComm-Config.json"
    return @{}
}

# Merge config and secrets (secrets take precedence)
# DEPRECATED: Kept for backward compatibility, but no longer merges secrets
function Merge-ConfigWithSecrets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        
        [PSCustomObject]$Secrets
    )
    
    if (-not $Secrets) {
        Write-Verbose "No secrets to merge"
        return $Config
    }
    
    Write-Verbose "Merging secrets into configuration..."
    
    # Deep clone config to avoid modifying original
    $merged = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    
    # Ensure licenses property exists
    if (-not $merged.PSObject.Properties['licenses']) {
        $merged | Add-Member -NotePropertyName 'licenses' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    
    # Apply VARA FM license if present
    if ($Secrets.licenses.varaFM.key) {
        $merged.licenses | Add-Member -NotePropertyName 'varaFM' -NotePropertyValue $Secrets.licenses.varaFM.key -Force
        Write-Verbose "Applied VARA FM license key"
    }
    
    # Apply account credentials if present
    if ($Secrets.accounts) {
        if (-not $merged.PSObject.Properties['accounts']) {
            $merged | Add-Member -NotePropertyName 'accounts' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        
        foreach ($prop in $Secrets.accounts.PSObject.Properties) {
            if ($prop.Name -notmatch '^_') {
                $merged.accounts | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                Write-Verbose "Applied account credentials: $($prop.Name)"
            }
        }
    }
    
    # Apply API keys if present
    if ($Secrets.apis) {
        if (-not $merged.PSObject.Properties['apis']) {
            $merged | Add-Member -NotePropertyName 'apis' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        
        foreach ($prop in $Secrets.apis.PSObject.Properties) {
            if ($prop.Value.key -and $prop.Name -notmatch '^_') {
                $merged.apis | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value.key -Force
                Write-Verbose "Applied API key: $($prop.Name)"
            }
        }
    }
    
    return $merged
}

# Initialize configuration with auto-detection
function Initialize-EmCommConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigFile,
        
        [string]$SecretsFile  # Deprecated - kept for compatibility
    )
    
    Write-Host "`n=== EmComm Configuration Initialization ===" -ForegroundColor Cyan
    
    # Ignore SecretsFile parameter (deprecated - all secrets in main config now)
    if ($SecretsFile) {
        Write-Verbose "SecretsFile parameter is deprecated - all configuration in $ConfigFile"
    }
    
    # Validate config file exists
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        Write-Host "Copy EmComm-Config.template.json to $ConfigFile and customize it" -ForegroundColor Yellow
        return $null
    }
    
    # Load configuration
    Write-Host "Loading configuration from: $ConfigFile" -ForegroundColor Cyan
    try {
        $config = Get-Content $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to parse configuration file: $_"
        return $null
    }
    
    # Validate required fields
    if (-not $config.operator.callsign -or $config.operator.callsign -eq "" -or $config.operator.callsign -eq "N0CALL") {
        Write-Error "Callsign is required in configuration file"
        Write-Host "Edit $ConfigFile and set operator.callsign to YOUR callsign" -ForegroundColor Yellow
        return $null
    }
    
    Write-Host "  Callsign: $($config.operator.callsign)" -ForegroundColor Green
    
    # Auto-detect COM port if requested
    if ($config.rig.device -eq 'auto') {
        if ($config.deployment.autoDetectPorts) {
            Write-Host "`nAuto-detecting radio COM port..." -ForegroundColor Cyan
            $ports = Get-AvailableComPorts
            
            if ($ports.Count -gt 0) {
                Write-Host "  Available COM ports:" -ForegroundColor Gray
                $ports | ForEach-Object {
                    Write-Host "    $($_.Port): $($_.Description)" -ForegroundColor Gray
                }
            }
            
            $detectedPort = Find-RadioComPort
            $config.rig.device = $detectedPort
            Write-Host "  Selected: $detectedPort" -ForegroundColor Green
        }
        else {
            Write-Warning "Auto-detect ports is disabled, using default COM3"
            $config.rig.device = "COM3"
        }
    }
    else {
        Write-Host "  COM Port: $($config.rig.device) (manual)" -ForegroundColor Green
    }
    
    # Auto-detect GPS location if requested
    if ($config.operator.locator -eq 'auto') {
        if ($config.deployment.autoDetectLocation) {
            Write-Host "`nDetecting GPS location..." -ForegroundColor Cyan
            $location = Get-GPSLocation -TimeoutSeconds 10
            
            if ($location) {
                $locator = ConvertTo-MaidenheadLocator -Latitude $location.Latitude -Longitude $location.Longitude -Precision 6
                $config.operator.locator = $locator
                
                # Add coordinates to operator info
                $config.operator | Add-Member -NotePropertyName 'latitude' -NotePropertyValue $location.Latitude -Force
                $config.operator | Add-Member -NotePropertyName 'longitude' -NotePropertyValue $location.Longitude -Force
                
                Write-Host "  Coordinates: $($location.Latitude), $($location.Longitude)" -ForegroundColor Green
                Write-Host "  Locator: $locator" -ForegroundColor Green
                if ($location.Accuracy) {
                    Write-Host "  Accuracy: ±$($location.Accuracy) meters" -ForegroundColor Gray
                }
            }
            else {
                Write-Warning "GPS detection failed"
                Write-Host "  Manually set locator in $ConfigFile" -ForegroundColor Yellow
                $config.operator.locator = ""
            }
        }
        else {
            Write-Warning "Auto-detect location is disabled"
            $config.operator.locator = ""
        }
    }
    else {
        Write-Host "  Grid Locator: $($config.operator.locator) (manual)" -ForegroundColor Green
    }
    
    # Load and merge secrets
    Write-Host "`nLoading secrets..." -ForegroundColor Cyan
    $secrets = Get-EmCommSecrets -SecretsFile $SecretsFile
    
    if ($secrets) {
        $config = Merge-ConfigWithSecrets -Config $config -Secrets $secrets
        Write-Host "  Secrets loaded and merged successfully" -ForegroundColor Green
    }
    else {
        Write-Host "  No secrets file found (license keys must be provided as parameters)" -ForegroundColor Yellow
    }
    
    Write-Host "`n=== Configuration Ready ===" -ForegroundColor Cyan
    return $config
}

# Export functions
Export-ModuleMember -Function @(
    'Get-AvailableComPorts',
    'Find-RadioComPort',
    'Get-GPSLocation',
    'ConvertTo-MaidenheadLocator',
    'Get-EmCommSecrets',
    'Merge-ConfigWithSecrets',
    'Initialize-EmCommConfig'
)
