# W1HKJ Software Auto-Installer
# Run PowerShell as Administrator

$DownloadRoot = "https://www.w1hkj.org/files/"
$TempDir = "$env:TEMP\W1HKJ_Installers"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# Define software packages and their installer names
$SoftwareList = @(
    @{ Name = "fldigi";   File = "fldigi/fldigi-4.2.09_setup.exe" },
    @{ Name = "flrig";    File = "flrig/flrig-2.0.09_setup.exe" },
    @{ Name = "flmsg";    File = "flmsg-latest_setup.exe" },
    @{ Name = "flamp";    File = "flamp-latest_setup.exe" },
    @{ Name = "fllog";    File = "fllog-latest_setup.exe" },
    @{ Name = "flnet";    File = "flnet-latest_setup.exe" },
    @{ Name = "flwkey";   File = "flwkey-latest_setup.exe" },
    @{ Name = "flwrap";   File = "flwrap-latest_setup.exe" },
    @{ Name = "flcluster";File = "flcluster-latest_setup.exe" },
    @{ Name = "flaa";     File = "flaa-latest_setup.exe" },
    @{ Name = "nanoIO";   File = "nanoIO-latest_setup.exe" },
    @{ Name = "kcat";     File = "kcat-latest_setup.exe" },
    @{ Name = "comptext"; File = "test_suite/comptext-1.0.1_setup.exe" }
    @{ Name = "comptty"; File = "test_suite/comptty-1.0.1_setup.exe" }
    @{ Name = "comptext"; File = "test_suite/linsim-2.0.6_setup.exe" }
    @{ Name = "comptext"; File = "test_suite/comptext-1.0.1_setup.exe" }
)

foreach ($app in $SoftwareList) {
    $url = "$DownloadRoot$($app.File)"
    $dest = Join-Path $TempDir $app.File

    Write-Host "Downloading $($app.Name) from $url ..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-Host "Installing $($app.Name)..."
        Start-Process -FilePath $dest -ArgumentList "/SILENT" -Wait
    }
    catch {
        Write-Warning "Failed to download or install $($app.Name): $_"
    }
}

Write-Host "All available W1HKJ software processed."
