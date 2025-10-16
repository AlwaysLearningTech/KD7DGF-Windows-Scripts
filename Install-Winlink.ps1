<#
.SYNOPSIS
    Install Winlink Express for amateur radio email
    
.DESCRIPTION
    Downloads and installs latest Winlink Express from downloads.winlink.org with silent installation.
    
.EXAMPLE
    .\Install-Winlink.ps1
    
.NOTES
    Requires Administrator privileges
    Logs to C:\Logs\Winlink_Install_YYYYMMDD_HHMMSS.log

.INTUNE WIN32 APP DEPLOYMENT
    Install command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-Winlink.ps1"
    Install behavior: System context
    Detection: File exists %ProgramFiles(x86)%\RMS Express\Winlink Express.exe
    Return codes: 0=success, 1=failure
#>

# Requires -RunAsAdministrator

# Logging setup
$LogDir = "C:\Logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\Winlink_Install_$Timestamp.log"

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

Write-Log "Starting Winlink Express installation"

$DownloadPage = "https://downloads.winlink.org/User%20Programs/"
$TempPath = "$env:TEMP\WinlinkInstaller.exe"

try {
    Write-Log "Fetching download page: $DownloadPage"
    $html = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing -ErrorAction Stop
    
    $link = ($html.Links | Where-Object { $_.href -match "Winlink_Express_install.*\.exe" } | Select-Object -First 1).href
    if (-not $link) {
        Write-Log "No installer link found on download page" -Level ERROR
        exit 1
    }

    if ($link -notmatch "^https?://") {
        $link = [System.Uri]::new($DownloadPage, $link).AbsoluteUri
    }

    Write-Log "Downloading Winlink Express from $link"
    Invoke-WebRequest -Uri $link -OutFile $TempPath -ErrorAction Stop
    Write-Log "Download completed: $TempPath"

    Write-Log "Starting silent installation"
    $Process = Start-Process -FilePath $TempPath -ArgumentList "/S" -Wait -PassThru -ErrorAction Stop
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "Winlink Express installed successfully"
        Remove-Item -Path $TempPath -Force -ErrorAction SilentlyContinue
        exit 0
    } else {
        Write-Log "Installation failed with exit code: $($Process.ExitCode)" -Level ERROR
        exit 1
    }
}
catch {
    Write-Log "Failed to download or install Winlink Express: $_" -Level ERROR
    exit 1
}
