<#
.SYNOPSIS
    Install Google Drive for Desktop and configure mount point
    
.DESCRIPTION
    Downloads and installs Google Drive for Desktop, configures mount as G:, and creates startup shortcut.
    
.EXAMPLE
    .\Install-GoogleDrive.ps1
    
.NOTES
    Requires Administrator privileges
    Logs to C:\Logs\GoogleDrive_Install_YYYYMMDD_HHMMSS.log

.INTUNE WIN32 APP DEPLOYMENT
    Install command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-GoogleDrive.ps1"
    Install behavior: System context
    Detection: File exists %ProgramFiles%\Google\Drive File Stream\GoogleDriveFS.exe
    Return codes: 0=success, 1=failure
#>

#Requires -RunAsAdministrator

# Logging setup
$LogDir = "C:\Logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\GoogleDrive_Install_$Timestamp.log"

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

Write-Log "Starting Google Drive for Desktop installation"

$InstallerPath = "$env:TEMP\GoogleDriveSetup.exe"
$DownloadUrl = "https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe"

try {
    Write-Log "Downloading Google Drive installer from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -ErrorAction Stop
    Write-Log "Download completed: $InstallerPath"

    Write-Log "Starting silent installation"
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList "/silent" -Wait -PassThru -ErrorAction Stop
    
    if ($Process.ExitCode -ne 0) {
        Write-Log "Installation failed with exit code: $($Process.ExitCode)" -Level ERROR
        exit 1
    }
    
    Write-Log "Installation completed successfully"
    Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue

    Write-Log "Configuring mount point as G:"
    $RegPath = "HKCU:\Software\Google\DriveFS"
    New-Item -Path $RegPath -Force -ErrorAction Stop | Out-Null
    Set-ItemProperty -Path $RegPath -Name "DefaultMountPoint" -Value "G:\" -ErrorAction Stop
    Write-Log "Mount point configured"

    $DriveExe = "$env:ProgramFiles\Google\Drive File Stream\GoogleDriveFS.exe"
    if (Test-Path $DriveExe) {
        Write-Log "Creating startup shortcut"
        $StartupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\GoogleDrive.lnk"
        $Shell = New-Object -ComObject WScript.Shell
        $Shortcut = $Shell.CreateShortcut($StartupPath)
        $Shortcut.TargetPath = $DriveExe
        $Shortcut.Save()
        Write-Log "Startup shortcut created"
    } else {
        Write-Log "GoogleDriveFS.exe not found at expected path, skipping startup shortcut" -Level WARNING
    }

    Write-Log "Google Drive for Desktop installation and configuration completed successfully"
    exit 0
}
catch {
    Write-Log "Failed to install or configure Google Drive: $_" -Level ERROR
    exit 1
}
