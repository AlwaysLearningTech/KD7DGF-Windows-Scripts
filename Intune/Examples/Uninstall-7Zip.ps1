<#
.SYNOPSIS
    Uninstall 7-Zip via Intune

.DESCRIPTION
    Uninstalls 7-Zip from Windows devices managed by Intune.

.EXAMPLE
    .\Uninstall-7Zip.ps1

.NOTES
    Author: KD7DGF
    Version: 1.0
    Date: 2025-10-11
#>

[CmdletBinding()]
param()

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
    
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Green }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
    }
    
    $logPath = "$env:ProgramData\Intune\Logs"
    if (-not (Test-Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }
    
    $logFile = Join-Path $logPath "Uninstall-7Zip.log"
    Add-Content -Path $logFile -Value $logMessage
}

try {
    Write-Log -Message "Starting uninstallation of 7-Zip" -Level Info
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log -Message "Script must be run as administrator" -Level Error
        exit 1
    }
    
    # Find 7-Zip in installed applications
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $app = $null
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $app = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -like "*7-Zip*" } | 
                Select-Object -First 1
            
            if ($app) { break }
        }
    }
    
    if (-not $app) {
        Write-Log -Message "7-Zip is not installed" -Level Warning
        exit 0
    }
    
    Write-Log -Message "Found 7-Zip: $($app.DisplayName) - Version: $($app.DisplayVersion)" -Level Info
    
    if ($app.UninstallString) {
        Write-Log -Message "Uninstalling 7-Zip..." -Level Info
        
        if ($app.UninstallString -like "msiexec*") {
            # MSI uninstall
            $uninstallArgs = $app.UninstallString -replace "msiexec.exe", "" -replace "/I", "/x"
            $uninstallArgs += " /qn /norestart"
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -Wait -PassThru
        } else {
            # EXE uninstall
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($app.UninstallString)`" /S" -Wait -PassThru
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Log -Message "7-Zip uninstallation completed successfully" -Level Info
            exit 0
        } else {
            Write-Log -Message "7-Zip uninstallation failed with exit code: $($process.ExitCode)" -Level Error
            exit $process.ExitCode
        }
    } else {
        Write-Log -Message "No uninstall string found for 7-Zip" -Level Error
        exit 1
    }
    
} catch {
    Write-Log -Message "Uninstallation failed: $($_.Exception.Message)" -Level Error
    exit 1
}
