<#
.SYNOPSIS
    Detect 7-Zip installation via Intune

.DESCRIPTION
    Detects whether 7-Zip is installed on the system.

.EXAMPLE
    .\Detection-7Zip.ps1

.NOTES
    Author: KD7DGF
    Version: 1.0
    Date: 2025-10-11
#>

try {
    # Check if 7-Zip is installed
    $7zipPath = "C:\Program Files\7-Zip\7z.exe"
    
    if (Test-Path $7zipPath) {
        $version = (Get-Item $7zipPath).VersionInfo.FileVersion
        Write-Host "7-Zip detected (Version: $version)"
        exit 0
    } else {
        # Not detected - exit with 0 but no output
        exit 0
    }
} catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
