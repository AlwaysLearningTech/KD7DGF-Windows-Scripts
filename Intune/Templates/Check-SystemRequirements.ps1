<#
.SYNOPSIS
    System Requirements Check for Intune Deployments

.DESCRIPTION
    Verifies that the system meets requirements before application installation.
    Can be used as a requirement rule in Intune or as a pre-check in install scripts.

.PARAMETER MinimumRAMGB
    Minimum RAM required in GB

.PARAMETER MinimumDiskSpaceGB
    Minimum free disk space required in GB on system drive

.PARAMETER MinimumOSVersion
    Minimum Windows version (e.g., "10.0.19041" for Windows 10 20H2)

.PARAMETER RequiredFeatures
    Array of Windows features that must be enabled

.EXAMPLE
    .\Check-SystemRequirements.ps1 -MinimumRAMGB 4 -MinimumDiskSpaceGB 10 -MinimumOSVersion "10.0.19041"

.NOTES
    Author: KD7DGF
    Version: 1.0
    Date: 2025-10-11
    
    Exit codes:
    0 = Requirements met
    1 = Requirements not met
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$MinimumRAMGB,
    
    [Parameter(Mandatory=$false)]
    [int]$MinimumDiskSpaceGB,
    
    [Parameter(Mandatory=$false)]
    [string]$MinimumOSVersion,
    
    [Parameter(Mandatory=$false)]
    [string[]]$RequiredFeatures,
    
    [Parameter(Mandatory=$false)]
    [switch]$OutputDetails
)

# Set error action preference
$ErrorActionPreference = "Stop"

function Write-Result {
    param(
        [string]$Check,
        [bool]$Passed,
        [string]$Details
    )
    
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    if ($OutputDetails) {
        Write-Host "[$status] $Check - $Details" -ForegroundColor $color
    }
    
    return $Passed
}

try {
    $allChecksPassed = $true
    
    # Check RAM
    if ($MinimumRAMGB) {
        $totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        $ramCheck = $totalRAM -ge $MinimumRAMGB
        $allChecksPassed = $allChecksPassed -and (Write-Result -Check "RAM" -Passed $ramCheck -Details "$totalRAM GB (Required: $MinimumRAMGB GB)")
    }
    
    # Check Disk Space
    if ($MinimumDiskSpaceGB) {
        $systemDrive = $env:SystemDrive
        $disk = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $systemDrive }
        $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $diskCheck = $freeSpaceGB -ge $MinimumDiskSpaceGB
        $allChecksPassed = $allChecksPassed -and (Write-Result -Check "Disk Space" -Passed $diskCheck -Details "$freeSpaceGB GB free (Required: $MinimumDiskSpaceGB GB)")
    }
    
    # Check OS Version
    if ($MinimumOSVersion) {
        $osVersion = [System.Environment]::OSVersion.Version
        $currentVersion = "$($osVersion.Major).$($osVersion.Minor).$($osVersion.Build)"
        
        try {
            $current = [Version]$currentVersion
            $required = [Version]$MinimumOSVersion
            $osCheck = $current -ge $required
        } catch {
            $osCheck = $currentVersion -ge $MinimumOSVersion
        }
        
        $allChecksPassed = $allChecksPassed -and (Write-Result -Check "OS Version" -Passed $osCheck -Details "$currentVersion (Required: $MinimumOSVersion)")
    }
    
    # Check Windows Features
    if ($RequiredFeatures) {
        foreach ($feature in $RequiredFeatures) {
            $featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
            
            if ($featureState) {
                $featureCheck = $featureState.State -eq "Enabled"
                $state = $featureState.State
            } else {
                $featureCheck = $false
                $state = "Not Found"
            }
            
            $allChecksPassed = $allChecksPassed -and (Write-Result -Check "Feature: $feature" -Passed $featureCheck -Details $state)
        }
    }
    
    # Check if system is 64-bit
    $is64Bit = [Environment]::Is64BitOperatingSystem
    $allChecksPassed = $allChecksPassed -and (Write-Result -Check "64-bit OS" -Passed $is64Bit -Details $(if ($is64Bit) { "Yes" } else { "No (32-bit)" }))
    
    # Final result
    if ($allChecksPassed) {
        if ($OutputDetails) {
            Write-Host "`n✓ All system requirements met" -ForegroundColor Green
        }
        exit 0
    } else {
        if ($OutputDetails) {
            Write-Host "`n✗ System requirements not met" -ForegroundColor Red
        }
        exit 1
    }
    
} catch {
    Write-Error "Requirements check failed: $($_.Exception.Message)"
    exit 1
}
