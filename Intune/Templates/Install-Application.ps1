<#
.SYNOPSIS
    Template script for installing applications via Intune

.DESCRIPTION
    This script provides a template for installing applications through Microsoft Intune.
    Modify the installation logic in the main section to match your application requirements.

.PARAMETER AppName
    Name of the application being installed

.PARAMETER InstallPath
    Custom installation path (optional)

.EXAMPLE
    .\Install-Application.ps1 -AppName "MyApp" -InstallPath "C:\Program Files\MyApp"

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
    [string]$InstallPath,
    
    [Parameter(Mandatory=$false)]
    [string]$InstallerPath,
    
    [Parameter(Mandatory=$false)]
    [string]$Arguments
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
    
    $logFile = Join-Path $logPath "Install-$AppName.log"
    Add-Content -Path $logFile -Value $logMessage
}

# Main installation logic
try {
    Write-Log -Message "Starting installation of $AppName" -Level Info
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log -Message "Script must be run as administrator" -Level Error
        exit 1
    }
    
    # Pre-installation checks
    Write-Log -Message "Performing pre-installation checks..." -Level Info
    
    # Check if application is already installed (modify based on your app)
    # Example: Check registry or file existence
    
    # Installation logic - Customize this section for your application
    if ($InstallerPath -and (Test-Path $InstallerPath)) {
        Write-Log -Message "Installing from: $InstallerPath" -Level Info
        
        # Determine installer type and install accordingly
        if ($InstallerPath -like "*.msi") {
            # MSI installation
            $msiArgs = "/i `"$InstallerPath`" /qn /norestart"
            if ($Arguments) {
                $msiArgs += " $Arguments"
            }
            Write-Log -Message "Executing: msiexec.exe $msiArgs" -Level Info
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Log -Message "MSI installation completed successfully" -Level Info
            } else {
                Write-Log -Message "MSI installation failed with exit code: $($process.ExitCode)" -Level Error
                exit $process.ExitCode
            }
        }
        elseif ($InstallerPath -like "*.exe") {
            # EXE installation
            $exeArgs = $Arguments
            if (-not $exeArgs) {
                $exeArgs = "/S /silent /quiet"  # Default silent arguments
            }
            Write-Log -Message "Executing: $InstallerPath $exeArgs" -Level Info
            $process = Start-Process -FilePath $InstallerPath -ArgumentList $exeArgs -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Log -Message "EXE installation completed successfully" -Level Info
            } else {
                Write-Log -Message "EXE installation failed with exit code: $($process.ExitCode)" -Level Error
                exit $process.ExitCode
            }
        }
        else {
            Write-Log -Message "Unsupported installer type" -Level Error
            exit 1
        }
    }
    else {
        Write-Log -Message "Installer path not provided or does not exist" -Level Warning
        Write-Log -Message "Add your custom installation logic here" -Level Info
        
        # Add your custom installation steps here
        # Example:
        # Copy-Item -Path "source" -Destination "destination" -Recurse
        # New-Item -Path $InstallPath -ItemType Directory -Force
    }
    
    # Post-installation tasks
    Write-Log -Message "Performing post-installation tasks..." -Level Info
    
    # Add any post-installation configurations here
    # Examples:
    # - Registry modifications
    # - Service configurations
    # - Shortcuts creation
    # - Environment variables
    
    Write-Log -Message "Installation of $AppName completed successfully" -Level Info
    exit 0
    
} catch {
    Write-Log -Message "Installation failed: $($_.Exception.Message)" -Level Error
    Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
