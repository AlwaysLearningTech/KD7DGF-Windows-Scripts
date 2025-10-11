<#
.SYNOPSIS
    Template script for uninstalling applications via Intune

.DESCRIPTION
    This script provides a template for uninstalling applications through Microsoft Intune.
    Modify the uninstallation logic in the main section to match your application requirements.

.PARAMETER AppName
    Name of the application being uninstalled

.PARAMETER ProductCode
    MSI product code (for MSI-based applications)

.EXAMPLE
    .\Uninstall-Application.ps1 -AppName "MyApp" -ProductCode "{12345678-1234-1234-1234-123456789012}"

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
    [string]$ProductCode,
    
    [Parameter(Mandatory=$false)]
    [string]$UninstallString
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Logging function
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Warning','Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Log to console
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Green }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
    }
    
    # Log to file
    $logPath = "$env:ProgramData\Intune\Logs"
    if (-not (Test-Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }
    
    $logFile = Join-Path $logPath "Uninstall-$AppName.log"
    Add-Content -Path $logFile -Value $logMessage
}

# Function to find application in registry
function Get-InstalledApplication {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName
    )
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
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

# Main uninstallation logic
try {
    Write-Log -Message "Starting uninstallation of $AppName" -Level Info
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log -Message "Script must be run as administrator" -Level Error
        exit 1
    }
    
    # Check if application is installed
    Write-Log -Message "Checking if $AppName is installed..." -Level Info
    
    # Uninstall using Product Code (MSI)
    if ($ProductCode) {
        Write-Log -Message "Uninstalling using Product Code: $ProductCode" -Level Info
        $msiArgs = "/x `"$ProductCode`" /qn /norestart"
        Write-Log -Message "Executing: msiexec.exe $msiArgs" -Level Info
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log -Message "MSI uninstallation completed successfully" -Level Info
        } else {
            Write-Log -Message "MSI uninstallation failed with exit code: $($process.ExitCode)" -Level Error
            exit $process.ExitCode
        }
    }
    # Uninstall using UninstallString
    elseif ($UninstallString) {
        Write-Log -Message "Uninstalling using uninstall string: $UninstallString" -Level Info
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $UninstallString" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log -Message "Uninstallation completed successfully" -Level Info
        } else {
            Write-Log -Message "Uninstallation failed with exit code: $($process.ExitCode)" -Level Error
            exit $process.ExitCode
        }
    }
    # Try to find and uninstall automatically
    else {
        Write-Log -Message "Searching for installed application..." -Level Info
        $installedApps = Get-InstalledApplication -AppName $AppName
        
        if ($installedApps.Count -eq 0) {
            Write-Log -Message "$AppName is not installed" -Level Warning
            exit 0
        }
        
        foreach ($app in $installedApps) {
            Write-Log -Message "Found: $($app.DisplayName) - Version: $($app.DisplayVersion)" -Level Info
            
            if ($app.UninstallString) {
                Write-Log -Message "Uninstalling using: $($app.UninstallString)" -Level Info
                
                # Handle different uninstall string formats
                if ($app.UninstallString -like "msiexec*") {
                    # MSI uninstall
                    $uninstallArgs = $app.UninstallString -replace "msiexec.exe", "" -replace "/I", "/x"
                    $uninstallArgs += " /qn /norestart"
                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -Wait -PassThru
                } else {
                    # EXE uninstall
                    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($app.UninstallString)`" /S /silent" -Wait -PassThru
                }
                
                if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                    Write-Log -Message "Uninstallation completed successfully" -Level Info
                } else {
                    Write-Log -Message "Uninstallation failed with exit code: $($process.ExitCode)" -Level Error
                }
            }
        }
    }
    
    # Post-uninstallation cleanup
    Write-Log -Message "Performing post-uninstallation cleanup..." -Level Info
    
    # Add any cleanup tasks here
    # Examples:
    # - Remove leftover directories
    # - Clean up registry entries
    # - Remove shortcuts
    
    Write-Log -Message "Uninstallation of $AppName completed successfully" -Level Info
    exit 0
    
} catch {
    Write-Log -Message "Uninstallation failed: $($_.Exception.Message)" -Level Error
    Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
