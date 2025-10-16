<#
.SYNOPSIS
    Install VARA HF and VARA FM modems for Winlink Express
    
.DESCRIPTION
    Downloads and installs VARA HF (free) and optionally VARA FM from rosmodem.wordpress.com.
    VARA FM requires a license key ($69 USD).
    
.PARAMETER IncludeFM
    Install VARA FM in addition to VARA HF (requires license purchase)
    
.PARAMETER LicenseKey
    VARA FM license key (format: XXXX-XXXX-XXXX-XXXX)
    
.PARAMETER ConfigFile
    Optional JSON configuration file for audio device pre-configuration
    
.EXAMPLE
    .\Install-VARAModem.ps1
    Installs VARA HF only (free)
    
.EXAMPLE
    .\Install-VARAModem.ps1 -IncludeFM -LicenseKey "XXXX-XXXX-XXXX-XXXX"
    Installs both VARA HF and VARA FM with license activation
    
.EXAMPLE
    .\Install-VARAModem.ps1 -ConfigFile "EmComm-Config.json"
    Installs with pre-configured audio devices from JSON
    
.NOTES
    Requires Administrator privileges
    Logs to C:\Logs\VARA_Install_YYYYMMDD_HHMMSS.log
    VARA HF: Free for amateur radio use
    VARA FM: $69 USD license from https://rosmodem.wordpress.com/

.INTUNE WIN32 APP DEPLOYMENT
    Install command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-VARAModem.ps1"
    Install behavior: System context
    Detection: File exists %ProgramFiles(x86)%\VARA\VARA.exe
    Return codes: 0=success, 1=failure
#>

# Requires -RunAsAdministrator

param(
    [switch]$IncludeFM,
    [string]$LicenseKey,
    [string]$ConfigFile
)

# Logging setup
$LogDir = "C:\Logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\VARA_Install_$Timestamp.log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )
    $LogMessage = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $LogMessage
    
    switch ($Level) {
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'WARNING' { Write-Host $Message -ForegroundColor Yellow }
        default   { Write-Host $Message }
    }
}

Write-Log "Starting VARA Modem installation"

# VARA download URLs (updated as of October 2025)
$VARAHFUrl = "https://rosmodem.wordpress.com/wp-content/uploads/2024/12/vara_hf_setup.exe"
$VARAFMUrl = "https://rosmodem.wordpress.com/wp-content/uploads/2024/12/vara_fm_setup.exe"

$TempDir = "$env:TEMP\VARA"
if (-not (Test-Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}

# Load configuration if provided
$Config = $null
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Write-Log "Loading configuration from $ConfigFile"
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Log "Configuration loaded successfully"
    }
    catch {
        Write-Log "Failed to load configuration: $_" -Level WARNING
    }
}

# Install VARA HF
try {
    Write-Log "Downloading VARA HF from $VARAHFUrl"
    $VARAHFInstaller = "$TempDir\vara_hf_setup.exe"
    Invoke-WebRequest -Uri $VARAHFUrl -OutFile $VARAHFInstaller -ErrorAction Stop
    Write-Log "Download completed: $VARAHFInstaller"

    Write-Log "Installing VARA HF (silent mode)"
    $Process = Start-Process -FilePath $VARAHFInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -ErrorAction Stop
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "VARA HF installed successfully"
    } else {
        Write-Log "VARA HF installation returned exit code: $($Process.ExitCode)" -Level WARNING
    }
}
catch {
    Write-Log "Failed to install VARA HF: $_" -Level ERROR
    exit 1
}

# Install VARA FM if requested
if ($IncludeFM) {
    try {
        Write-Log "Downloading VARA FM from $VARAFMUrl"
        $VARAFMInstaller = "$TempDir\vara_fm_setup.exe"
        Invoke-WebRequest -Uri $VARAFMUrl -OutFile $VARAFMInstaller -ErrorAction Stop
        Write-Log "Download completed: $VARAFMInstaller"

        Write-Log "Installing VARA FM (silent mode)"
        $Process = Start-Process -FilePath $VARAFMInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -ErrorAction Stop
        
        if ($Process.ExitCode -eq 0) {
            Write-Log "VARA FM installed successfully"
        } else {
            Write-Log "VARA FM installation returned exit code: $($Process.ExitCode)" -Level WARNING
        }
        
        # Apply license key if provided
        if ($LicenseKey) {
            Write-Log "Applying VARA FM license key"
            $VARAFMIni = "$env:ProgramFiles(x86)\VARA FM\VARA FM.ini"
            if (Test-Path $VARAFMIni) {
                $IniContent = Get-Content $VARAFMIni -Raw
                $IniContent = $IniContent -replace "LicenseKey=.*", "LicenseKey=$LicenseKey"
                Set-Content -Path $VARAFMIni -Value $IniContent -Force
                Write-Log "License key applied"
            } else {
                Write-Log "VARA FM.ini not found, license must be entered manually" -Level WARNING
            }
        }
    }
    catch {
        Write-Log "Failed to install VARA FM: $_" -Level ERROR
    }
}

# Configure audio devices if config provided
if ($Config -and $Config.audio) {
    Write-Log "Configuring audio devices from JSON"
    
    # VARA HF configuration
    $VARAHFIni = "$env:ProgramFiles(x86)\VARA\VARA.ini"
    if (Test-Path $VARAHFIni) {
        try {
            $IniContent = Get-Content $VARAHFIni -Raw
            
            if ($Config.audio.captureDevice) {
                $IniContent = $IniContent -replace "SoundCardName=.*", "SoundCardName=$($Config.audio.captureDevice)"
                Write-Log "Set VARA HF capture device: $($Config.audio.captureDevice)"
            }
            
            if ($Config.audio.playbackDevice) {
                $IniContent = $IniContent -replace "SoundCardNameOutput=.*", "SoundCardNameOutput=$($Config.audio.playbackDevice)"
                Write-Log "Set VARA HF playback device: $($Config.audio.playbackDevice)"
            }
            
            Set-Content -Path $VARAHFIni -Value $IniContent -Force
            Write-Log "VARA HF audio configuration applied"
        }
        catch {
            Write-Log "Failed to configure VARA HF audio: $_" -Level WARNING
        }
    }
    
    # VARA FM configuration
    if ($IncludeFM) {
        $VARAFMIni = "$env:ProgramFiles(x86)\VARA FM\VARA FM.ini"
        if (Test-Path $VARAFMIni) {
            try {
                $IniContent = Get-Content $VARAFMIni -Raw
                
                if ($Config.audio.captureDevice) {
                    $IniContent = $IniContent -replace "SoundCardName=.*", "SoundCardName=$($Config.audio.captureDevice)"
                    Write-Log "Set VARA FM capture device: $($Config.audio.captureDevice)"
                }
                
                if ($Config.audio.playbackDevice) {
                    $IniContent = $IniContent -replace "SoundCardNameOutput=.*", "SoundCardNameOutput=$($Config.audio.playbackDevice)"
                    Write-Log "Set VARA FM playback device: $($Config.audio.playbackDevice)"
                }
                
                Set-Content -Path $VARAFMIni -Value $IniContent -Force
                Write-Log "VARA FM audio configuration applied"
            }
            catch {
                Write-Log "Failed to configure VARA FM audio: $_" -Level WARNING
            }
        }
    }
}

# Cleanup
Write-Log "Cleaning up temporary files"
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "VARA Modem installation completed successfully"
exit 0
