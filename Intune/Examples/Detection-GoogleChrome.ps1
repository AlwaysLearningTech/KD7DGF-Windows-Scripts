<#
.SYNOPSIS
    Detect Google Chrome installation via Intune

.DESCRIPTION
    Detects whether Google Chrome is installed on the system.

.EXAMPLE
    .\Detection-GoogleChrome.ps1

.NOTES
    Author: KD7DGF
    Version: 1.0
    Date: 2025-10-11
#>

try {
    # Check common installation paths for Chrome
    $chromePaths = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    )
    
    foreach ($path in $chromePaths) {
        if (Test-Path $path) {
            $version = (Get-Item $path).VersionInfo.FileVersion
            Write-Host "Google Chrome detected (Version: $version)"
            exit 0
        }
    }
    
    # Not detected - exit with 0 but no output
    exit 0
    
} catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
