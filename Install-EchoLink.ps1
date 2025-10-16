<#
.SYNOPSIS
    Install EchoLink for VoIP amateur radio linking
    
.DESCRIPTION
    Downloads and installs latest EchoLink from echolink.org with optional
    pre-configuration for callsign and validation.
    
.PARAMETER ConfigFile
    Optional JSON configuration file with callsign settings
    
.EXAMPLE
    .\Install-EchoLink.ps1
    Basic installation without pre-configuration
    
.EXAMPLE
    .\Install-EchoLink.ps1 -ConfigFile "EmComm-Config.json"
    Install with pre-configured callsign
    
.NOTES
    Requires Administrator privileges
    Requires amateur radio license validation
    Logs to C:\Logs\EchoLink_Install_YYYYMMDD_HHMMSS.log

.INTUNE WIN32 APP DEPLOYMENT
    Install command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-EchoLink.ps1"
    Install behavior: System context
    Detection: File exists %ProgramFiles(x86)%\K1RFD\EchoLink\EchoLink.exe
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
$LogFile = "$LogDir\EchoLink_Install_$Timestamp.log"

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

Write-Log "Starting EchoLink installation"

# EchoLink download page
$DownloadPage = "https://secure.echolink.org/download.htm"

$TempDir = "$env:TEMP\EchoLink"
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
    Write-Log "Fetching EchoLink download page"
    $html = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing -ErrorAction Stop
    
    # Find installer link
    $link = ($html.Links | Where-Object { $_.href -match "EchoLink.*\.exe" } | Select-Object -First 1).href
    
    if (-not $link) {
        Write-Log "No installer found, using direct download URL" -Level WARNING
        $link = "https://secure.echolink.org/installers/EchoLink.exe"
    }
    
    if ($link -notmatch "^https?://") {
        $link = [System.Uri]::new($DownloadPage, $link).AbsoluteUri
    }

    Write-Log "Downloading EchoLink from $link"
    $InstallerPath = "$TempDir\EchoLink.exe"
    Invoke-WebRequest -Uri $link -OutFile $InstallerPath -ErrorAction Stop
    Write-Log "Download completed: $InstallerPath"

    Write-Log "Installing EchoLink"
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -ErrorAction Stop
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "EchoLink installed successfully"
    } else {
        Write-Log "EchoLink installation returned exit code: $($Process.ExitCode)" -Level WARNING
    }
}
catch {
    Write-Log "Failed to install EchoLink: $_" -Level ERROR
    exit 1
}

# Pre-configure if config provided
if ($Config -and $Config.operator.callsign) {
    Write-Log "Pre-configuring EchoLink with callsign"
    
    $CallSign = $Config.operator.callsign
    $Name = if ($Config.operator.name) { $Config.operator.name } else { "" }
    $QTH = if ($Config.operator.qth) { $Config.operator.qth } else { "" }
    
    # EchoLink stores config in registry
    $RegPath = "HKCU:\Software\K1RFD\EchoLink"
    
    try {
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $RegPath -Name "Callsign" -Value $CallSign -Type String
        Write-Log "Set callsign: $CallSign"
        
        if ($Name) {
            Set-ItemProperty -Path $RegPath -Name "Name" -Value $Name -Type String
            Write-Log "Set name: $Name"
        }
        
        if ($QTH) {
            Set-ItemProperty -Path $RegPath -Name "QTH" -Value $QTH -Type String
            Write-Log "Set QTH: $QTH"
        }
        
        Write-Log "EchoLink pre-configuration completed"
        Write-Log "User must still validate license at https://secure.echolink.org/validation/" -Level WARNING
    }
    catch {
        Write-Log "Failed to pre-configure EchoLink: $_" -Level WARNING
    }
}

# Cleanup
Write-Log "Cleaning up temporary files"
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "EchoLink installation completed successfully"
Write-Log "License validation required at https://secure.echolink.org/validation/" -Level INFO
exit 0
