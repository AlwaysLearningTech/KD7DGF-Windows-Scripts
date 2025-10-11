# Winlink Express Installer (always fetches latest version)
# Intune Detection Rule (example):
#   Rule type: File
#   Path: %ProgramFiles(x86)%\RMS Express
#   File or folder: Winlink Express.exe
#   Detection method: File exists

# Define download page and temp path
$DownloadPage = "https://downloads.winlink.org/User%20Programs/"
$TempPath = "$env:TEMP\WinlinkInstaller.exe"

# Scrape the download page for the latest installer link
try {
    $html = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing
    $link = ($html.Links | Where-Object { $_.href -match "Winlink_Express_install.*\.exe" } | Select-Object -First 1).href
    if (-not $link) { throw "No installer link found." }

    # Build full URL if relative
    if ($link -notmatch "^https?://") {
        $link = [System.Uri]::new($DownloadPage, $link).AbsoluteUri
    }

    Write-Output "Downloading latest Winlink Express from $link"
    Invoke-WebRequest -Uri $link -OutFile $TempPath

    # Run silent install
    Start-Process -FilePath $TempPath -ArgumentList "/S" -Wait
}
catch {
    Write-Error "Failed to download or install Winlink Express: $_"
    exit 1
}
