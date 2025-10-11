# Google Drive for Desktop install + mount configuration
# Intune Detection Rule (example):
#   Rule type: File
#   Path: %ProgramFiles%\Google\Drive File Stream
#   File or folder: GoogleDriveFS.exe
#   Detection method: File exists

$InstallerPath = "$env:TEMP\GoogleDriveSetup.exe"
Invoke-WebRequest -Uri "https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe" -OutFile $InstallerPath

Start-Process -FilePath $InstallerPath -ArgumentList "/silent" -Wait

$RegPath = "HKCU:\Software\Google\DriveFS"
New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name "DefaultMountPoint" -Value "G:\"

$StartupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\GoogleDrive.lnk"
$DriveExe = "$env:ProgramFiles\Google\Drive File Stream\GoogleDriveFS.exe"
if (Test-Path $DriveExe) {
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($StartupPath)
    $Shortcut.TargetPath = $DriveExe
    $Shortcut.Save()
}
