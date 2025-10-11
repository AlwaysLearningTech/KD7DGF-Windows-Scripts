# W1HKJ Suite Installer (fldigi, flrig, flmsg, flamp, flwrap)
# Intune Detection Rule (example for fldigi):
#   Rule type: File
#   Path: %ProgramFiles(x86)%\fldigi
#   File or folder: fldigi.exe
#   Detection method: File exists
#
# Repeat similar rules for flrig.exe, flmsg.exe, etc. if deploying separately.

$apps = @(
    @{Name="fldigi"; Url="https://downloads.sourceforge.net/project/fldigi/fldigi/fldigi-4.1.26_setup.exe"; Installer="fldigi_setup.exe"},
    @{Name="flrig"; Url="https://downloads.sourceforge.net/project/fldigi/flrig/flrig-1.4.7_setup.exe"; Installer="flrig_setup.exe"},
    @{Name="flmsg"; Url="https://downloads.sourceforge.net/project/fldigi/flmsg/flmsg-4.0.23_setup.exe"; Installer="flmsg_setup.exe"}
    # Add others as needed
)

foreach ($app in $apps) {
    $OutFile = "$env:TEMP\$($app.Installer)"
    Invoke-WebRequest -Uri $app.Url -OutFile $OutFile
    Start-Process -FilePath $OutFile -ArgumentList "/S" -Wait
}
