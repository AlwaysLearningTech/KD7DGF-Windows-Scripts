<#
.SYNOPSIS
    Template script for detecting applications via Intune

.DESCRIPTION
    This script provides a template for detecting whether applications are installed.
    Intune uses this script to determine the installation state of an application.
    
    Detection scripts should:
    - Exit with code 0 and write output if application is detected
    - Exit with code 0 without output if application is not detected
    - Exit with code 1 if an error occurs

.PARAMETER AppName
    Name of the application to detect

.PARAMETER Version
    Minimum version required (optional)

.EXAMPLE
    .\Detection-Application.ps1 -AppName "MyApp" -Version "1.0.0"

.NOTES
    Author: KD7DGF
    Version: 1.0
    Date: 2025-10-11
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPath,
    
    [Parameter(Mandatory=$false)]
    [string]$RegistryPath,
    
    [Parameter(Mandatory=$false)]
    [string]$RegistryValue
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to search for application in registry
function Get-InstalledApplication {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName
    )
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $installedApps = @()
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $installedApps += Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -like "*$AppName*" }
        }
    }
    
    return $installedApps
}

# Function to compare versions
function Compare-Version {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstalledVersion,
        
        [Parameter(Mandatory=$true)]
        [string]$RequiredVersion
    )
    
    try {
        $installed = [Version]$InstalledVersion
        $required = [Version]$RequiredVersion
        
        return $installed -ge $required
    } catch {
        # If version comparison fails, do string comparison
        return $InstalledVersion -ge $RequiredVersion
    }
}

try {
    $detected = $false
    $detectionMessage = ""
    
    # Method 1: Check by file path
    if ($InstallPath -and (Test-Path $InstallPath)) {
        $detected = $true
        $detectionMessage = "Application detected at: $InstallPath"
        
        # If version check is required and it's an executable
        if ($Version -and $InstallPath -like "*.exe") {
            $fileVersion = (Get-Item $InstallPath).VersionInfo.FileVersion
            if ($fileVersion) {
                if (Compare-Version -InstalledVersion $fileVersion -RequiredVersion $Version) {
                    $detectionMessage += " (Version: $fileVersion)"
                } else {
                    $detected = $false
                    $detectionMessage = "Application found but version $fileVersion is less than required $Version"
                }
            }
        }
    }
    
    # Method 2: Check by registry path
    if (-not $detected -and $RegistryPath) {
        if (Test-Path $RegistryPath) {
            if ($RegistryValue) {
                $regValue = Get-ItemProperty -Path $RegistryPath -Name $RegistryValue -ErrorAction SilentlyContinue
                if ($regValue) {
                    $detected = $true
                    $detectionMessage = "Application detected via registry: $RegistryPath\$RegistryValue"
                }
            } else {
                $detected = $true
                $detectionMessage = "Application detected via registry: $RegistryPath"
            }
        }
    }
    
    # Method 3: Search in installed applications
    if (-not $detected) {
        $installedApps = Get-InstalledApplication -AppName $AppName
        
        if ($installedApps.Count -gt 0) {
            foreach ($app in $installedApps) {
                # Check version if specified
                if ($Version -and $app.DisplayVersion) {
                    if (Compare-Version -InstalledVersion $app.DisplayVersion -RequiredVersion $Version) {
                        $detected = $true
                        $detectionMessage = "Application detected: $($app.DisplayName) (Version: $($app.DisplayVersion))"
                        break
                    }
                } else {
                    $detected = $true
                    $versionInfo = if ($app.DisplayVersion) { " (Version: $($app.DisplayVersion))" } else { "" }
                    $detectionMessage = "Application detected: $($app.DisplayName)$versionInfo"
                    break
                }
            }
        }
    }
    
    # Output result
    if ($detected) {
        Write-Host $detectionMessage
        exit 0
    } else {
        # Application not detected - exit with 0 but no output
        exit 0
    }
    
} catch {
    # Error occurred during detection
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
