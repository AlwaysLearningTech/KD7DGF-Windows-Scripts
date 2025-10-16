<#
.SYNOPSIS
    Install Anytone AT-D878UV CPS (Customer Programming Software)
    
.DESCRIPTION
    Downloads and installs latest Anytone AT-D878UVII Plus V2 CPS from Bridgecom Systems.
    Includes both programming software and USB drivers.
    
.PARAMETER ConfigFile
    Optional JSON configuration file for pre-loading operator settings
    
.EXAMPLE
    .\Install-AnytoneD878CPS.ps1
    Install latest D878 CPS
    
.EXAMPLE
    .\Install-AnytoneD878CPS.ps1 -ConfigFile "EmComm-Config.json"
    Install with pre-configured operator details
    
.NOTES
    Requires Administrator privileges
    Logs to C:\Logs\AnytoneD878CPS_Install_YYYYMMDD_HHMMSS.log
    For AT-D878UVII Plus V2 model only

.INTUNE WIN32 APP DEPLOYMENT
    Install command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-AnytoneD878CPS.ps1"
    Install behavior: System context
    Detection: File exists %ProgramFiles(x86)%\AnyTone\D878UV_V2\D878UV.exe
    Return codes: 0=success, 1=failure
#>

# Requires -RunAsAdministrator

param(
    [string]$ConfigFile
)

# Logging setup
$LogDir = "C:\Logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\AnytoneD878CPS_Install_$Timestamp.log"

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

Write-Log "Starting Anytone AT-D878UV V2 CPS installation"

# Bridgecom download page
$DownloadPage = "https://support.bridgecomsystems.com/anytone-878-v2-model-cps-firmware-downloads"

$TempDir = "$env:TEMP\AnytoneD878CPS"
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

try {
    Write-Log "Fetching Anytone D878 V2 CPS download page"
    $html = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing -ErrorAction Stop
    
    # Find latest CPS download link (usually a .zip file)
    $link = ($html.Links | Where-Object { 
        $_.href -match "D878.*V2.*CPS.*\.zip" -or $_.href -match "878.*CPS.*\.zip"
    } | Select-Object -First 1).href
    
    if (-not $link) {
        Write-Log "Could not find CPS download link automatically" -Level WARNING
        Write-Log "Using direct download URL pattern" -Level INFO
        # Fallback to common URL pattern (may need updating)
        $link = "https://support.bridgecomsystems.com/s/article/anytone-878-v2-model-cps-firmware-downloads"
        Write-Log "Please download CPS manually from: $DownloadPage" -Level ERROR
        exit 1
    }
    
    if ($link -notmatch "^https?://") {
        $BaseUrl = "https://support.bridgecomsystems.com"
        $link = "$BaseUrl$link"
    }

    Write-Log "Downloading Anytone D878 V2 CPS from $link"
    $ZipPath = "$TempDir\D878_CPS.zip"
    Invoke-WebRequest -Uri $link -OutFile $ZipPath -ErrorAction Stop
    Write-Log "Download completed: $ZipPath"

    Write-Log "Extracting CPS package"
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
    Write-Log "Extraction completed"
    
    # Find installer executable
    $Installer = Get-ChildItem -Path $TempDir -Filter "*.exe" -Recurse | 
                 Where-Object { $_.Name -match "setup|install|D878" } | 
                 Select-Object -First 1
    
    if (-not $Installer) {
        Write-Log "No installer found in package" -Level ERROR
        Write-Log "Manual installation may be required" -Level ERROR
        exit 1
    }
    
    Write-Log "Running installer: $($Installer.FullName)"
    $Process = Start-Process -FilePath $Installer.FullName -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -ErrorAction Stop
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "Anytone D878 V2 CPS installed successfully"
    } else {
        Write-Log "Installation returned exit code: $($Process.ExitCode)" -Level WARNING
    }
}
catch {
    Write-Log "Failed to install Anytone D878 V2 CPS: $_" -Level ERROR
    Write-Log "Please download manually from: $DownloadPage" -Level ERROR
    exit 1
}

# Install USB drivers
Write-Log "Installing Anytone USB drivers"
$DriverPath = Get-ChildItem -Path $TempDir -Filter "*.inf" -Recurse | Select-Object -First 1

if ($DriverPath) {
    try {
        Write-Log "Found driver: $($DriverPath.FullName)"
        & pnputil.exe /add-driver $DriverPath.FullName /install 2>&1 | ForEach-Object { Write-Log $_ }
        Write-Log "USB drivers installed"
    }
    catch {
        Write-Log "Failed to install USB drivers: $_" -Level WARNING
        Write-Log "Drivers may need manual installation" -Level WARNING
    }
} else {
    Write-Log "No driver files found in package" -Level WARNING
}

# Cleanup
Write-Log "Cleaning up temporary files"
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "Anytone AT-D878UV V2 CPS installation completed"
Write-Log "Connect radio via USB and launch CPS from Start Menu" -Level INFO
exit 0
