<#
.SYNOPSIS
    Install Google Chrome via Intune

.DESCRIPTION
    Installs Google Chrome MSI package for Windows devices managed by Intune.

.EXAMPLE
    .\Install-GoogleChrome.ps1

.NOTES
    Author: KD7DGF
    Version: 1.0
    Date: 2025-10-11
    
    Download the Chrome MSI from: https://cloud.google.com/chrome-enterprise/browser/download/
    Place the MSI file in the same directory as this script.
#>

[CmdletBinding()]
param()

# Set error action preference
$ErrorActionPreference = "Stop"

# Configuration
$AppName = "Google Chrome"
$InstallerName = "googlechromestandaloneenterprise64.msi"

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
    
    $logFile = Join-Path $logPath "Install-GoogleChrome.log"
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
    $installerPath = Join-Path $ScriptPath $InstallerName
    
    if (-not (Test-Path $installerPath)) {
        Write-Log -Message "Chrome installer not found at: $installerPath" -Level Error
        exit 1
    }
    
    Write-Log -Message "Found installer: $installerPath" -Level Info
    
    # Install Google Chrome with silent parameters
    Write-Log -Message "Installing Google Chrome..." -Level Info
    $msiArgs = "/i `"$installerPath`" /qn /norestart"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        Write-Log -Message "Google Chrome installation completed successfully" -Level Info
        exit 0
    } else {
        Write-Log -Message "Google Chrome installation failed with exit code: $($process.ExitCode)" -Level Error
        exit $process.ExitCode
    }
    
} catch {
    Write-Log -Message "Installation failed: $($_.Exception.Message)" -Level Error
    exit 1
}
