<#
.SYNOPSIS
    Install JS8Call for weak signal keyboard-to-keyboard communications
    
.DESCRIPTION
    Downloads and installs latest JS8Call from js8call.com with optional
    pre-configuration for callsign, grid square, and audio devices.
    
.PARAMETER ConfigFile
    Optional JSON configuration file with operator and audio settings
    
.EXAMPLE
    .\Install-JS8Call.ps1
    Basic installation without pre-configuration
    
.EXAMPLE
    .\Install-JS8Call.ps1 -ConfigFile "EmComm-Config.json"
    Install with pre-configured callsign, grid, and audio devices
    
.NOTES
    Requires Administrator privileges
    Logs to C:\Logs\JS8Call_Install_YYYYMMDD_HHMMSS.log

.INTUNE WIN32 APP DEPLOYMENT
    Install command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-JS8Call.ps1"
    Install behavior: System context
    Detection: File exists %ProgramFiles(x86)%\JS8Call\JS8Call.exe
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
$LogFile = "$LogDir\JS8Call_Install_$Timestamp.log"

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

Write-Log "Starting JS8Call installation"

# JS8Call download page
$DownloadPage = "http://files.js8call.com/latest.html"

$TempDir = "$env:TEMP\JS8Call"
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
    Write-Log "Fetching JS8Call download page"
    $html = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing -ErrorAction Stop
    
    # Find Windows 64-bit installer
    $link = ($html.Links | Where-Object { $_.href -match "js8call.*-win64\.exe" } | Select-Object -First 1).href
    
    if (-not $link) {
        Write-Log "No installer found on download page" -Level ERROR
        exit 1
    }
    
    if ($link -notmatch "^https?://") {
        $link = "http://files.js8call.com/$link"
    }

    Write-Log "Downloading JS8Call from $link"
    $InstallerPath = "$TempDir\JS8Call-installer.exe"
    Invoke-WebRequest -Uri $link -OutFile $InstallerPath -ErrorAction Stop
    Write-Log "Download completed: $InstallerPath"

    Write-Log "Installing JS8Call"
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -ErrorAction Stop
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "JS8Call installed successfully"
    } else {
        Write-Log "JS8Call installation returned exit code: $($Process.ExitCode)" -Level WARNING
    }
}
catch {
    Write-Log "Failed to install JS8Call: $_" -Level ERROR
    exit 1
}

# Pre-configure if config provided
if ($Config) {
    Write-Log "Configuring JS8Call settings"
    
    $JS8ConfigDir = "$env:LOCALAPPDATA\JS8Call"
    if (-not (Test-Path $JS8ConfigDir)) {
        New-Item -Path $JS8ConfigDir -ItemType Directory -Force | Out-Null
    }
    
    $CallSign = if ($Config.operator.callsign) { $Config.operator.callsign } else { "" }
    $Grid = if ($Config.operator.locator) { $Config.operator.locator } else { "" }
    $CaptureDevice = if ($Config.audio.captureDevice) { $Config.audio.captureDevice } else { "" }
    $PlaybackDevice = if ($Config.audio.playbackDevice) { $Config.audio.playbackDevice } else { "" }
    
    # Create JS8Call.ini configuration
    $IniContent = @"
[Configuration]
MyCall=$CallSign
MyGrid=$Grid
AudioInputDevice=$CaptureDevice
AudioOutputDevice=$PlaybackDevice

[Station]
Name=$($Config.operator.name)
QTH=$($Config.operator.qth)

[Rig]
RigName=None
PTT=VOX
"@

    # If rig configuration exists, add it
    if ($Config.rig -and $Config.rig.enabled) {
        if ($Config.rig.useFlrig) {
            $IniContent += @"

[Rig]
RigName=Hamlib NET rigctl
NetworkServer=127.0.0.1
NetworkPort=4532
PTT=CAT
"@
        } else {
            $RigName = if ($Config.rig.model) { $Config.rig.model } else { "None" }
            $IniContent += @"

[Rig]
RigName=$RigName
SerialPort=$($Config.rig.device)
SerialRate=$($Config.rig.baudRate)
PTT=CAT
"@
        }
    }

    $IniPath = "$JS8ConfigDir\JS8Call.ini"
    Set-Content -Path $IniPath -Value $IniContent -Force
    Write-Log "Configuration created at $IniPath"
}

# Cleanup
Write-Log "Cleaning up temporary files"
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "JS8Call installation completed successfully"
exit 0
