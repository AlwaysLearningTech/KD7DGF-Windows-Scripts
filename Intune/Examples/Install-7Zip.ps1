<#
.SYNOPSIS
    Install 7-Zip via Intune

.DESCRIPTION
    Installs 7-Zip MSI package for Windows devices managed by Intune.

.EXAMPLE
    .\Install-7Zip.ps1

.NOTES
    Author: KD7DGF
    Version: 1.0
    Date: 2025-10-11
    
    Download the latest 7-Zip MSI from: https://www.7-zip.org/download.html
    Place the MSI file in the same directory as this script.
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Stop"

# Configuration
$AppName = "7-Zip"
$InstallerName = "7z*-x64.msi"  # Adjust based on actual MSI filename

# Get script directory
$ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

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
    
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Green }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
    }
    
    $logPath = "$env:ProgramData\Intune\Logs"
    if (-not (Test-Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }
    
    $logFile = Join-Path $logPath "Install-7Zip.log"
    Add-Content -Path $logFile -Value $logMessage
}

try {
    Write-Log -Message "Starting installation of $AppName" -Level Info
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log -Message "Script must be run as administrator" -Level Error
        exit 1
    }
    
    # Find the installer
    $installer = Get-ChildItem -Path $ScriptPath -Filter $InstallerName | Select-Object -First 1
    
    if (-not $installer) {
        Write-Log -Message "7-Zip installer not found in script directory" -Level Error
        Write-Log -Message "Expected pattern: $InstallerName" -Level Error
        exit 1
    }
    
    $installerPath = $installer.FullName
    Write-Log -Message "Found installer: $installerPath" -Level Info
    
    # Install 7-Zip
    Write-Log -Message "Installing 7-Zip..." -Level Info
    $msiArgs = "/i `"$installerPath`" /qn /norestart"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        Write-Log -Message "7-Zip installation completed successfully" -Level Info
        exit 0
    } else {
        Write-Log -Message "7-Zip installation failed with exit code: $($process.ExitCode)" -Level Error
        exit $process.ExitCode
    }
    
} catch {
    Write-Log -Message "Installation failed: $($_.Exception.Message)" -Level Error
    exit 1
}
