<#
.SYNOPSIS
    PowerShell 7 Clean Install Script
    
.DESCRIPTION
    Removes existing PowerShell 7 MSI installation (if present) and performs a clean 
    installation of the latest PowerShell 7 using winget.
    
.NOTES
    Version: 1.0
    Author: KD7DGF
    Requires: Administrator privileges
    
.EXAMPLE
    .\Install-PowerShell7.ps1
    
.INTUNE WIN32 APP DEPLOYMENT
    Package Preparation:
        1. Place Install-PowerShell7.ps1 in a folder
        2. Use Microsoft Win32 Content Prep Tool:
           IntuneWinAppUtil.exe -c <source_folder> -s Install-PowerShell7.ps1 -o <output_folder>
        3. Upload the generated .intunewin file to Intune
    
    Program Settings:
        Install command: 
            powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "Install-PowerShell7.ps1"
        
        Uninstall command:
            msiexec.exe /x {A8E37C8B-EB15-4D2A-BF0C-C1AFA0D7DF40} /quiet /norestart
            (Note: Product GUID may vary by version - check registry or use winget uninstall)
        
        Alternative Uninstall (using winget):
            powershell.exe -ExecutionPolicy Bypass -Command "winget uninstall --id Microsoft.PowerShell --silent"
        
        Install behavior: System
        Device restart behavior: Determine behavior based on return codes
    
    Requirements:
        Operating system: Windows 10 1607+ or Windows 11
        Architecture: x64
        Minimum OS: Windows 10 1607 (Build 14393)
        Disk space required: 200 MB
    
    Detection Rules:
        Rule format: Use custom detection script
        Script type: PowerShell
        Script content:
            try {
                $pwsh7Path = "${env:ProgramFiles}\PowerShell\7\pwsh.exe"
                if (Test-Path $pwsh7Path) {
                    $version = & $pwsh7Path -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
                    if ($version -and [version]$version -ge [version]"7.0.0") {
                        Write-Host "PowerShell 7 detected: $version"
                        exit 0
                    }
                }
                exit 1
            }
            catch {
                exit 1
            }
        
        Alternative Detection - Registry:
            Path: HKLM:\SOFTWARE\Microsoft\PowerShell\7\InstalledVersions\*
            Value: Install
            Type: String
            Operator: Exists
        
        Alternative Detection - File:
            Path: C:\Program Files\PowerShell\7
            File: pwsh.exe
            Detection method: File or folder exists
    
    Return Codes:
        0    = Success
        1    = Failed
        3010 = Success (restart required)
        1641 = Success (restart initiated)
    
    Dependencies:
        None (script will install winget if needed)
    
    Supersedence:
        Can supersede any older PowerShell 7 MSI installations
    
    Assignments:
        Recommended: Available for enrolled devices
        Or: Required for specific device groups
        User context: Not available (requires System context)
#>

#Requires -RunAsAdministrator

# Initialize logging
$LogDir = "C:\Logs"
$LogFile = Join-Path $LogDir "PowerShell7_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create log directory if it doesn't exist
try {
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    }
}
catch {
    Write-Error "Failed to create log directory: $_"
    exit 1
}

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $logMessage
    
    # Write to console with color
    switch ($Level) {
        'INFO'    { Write-Host $logMessage -ForegroundColor Cyan }
        'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logMessage -ForegroundColor Red }
        'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
    }
}

# Function to uninstall PowerShell 7 MSI
function Uninstall-PowerShell7MSI {
    Write-Log "Checking for existing PowerShell 7 MSI installation..."
    
    try {
        # Check both 64-bit and 32-bit registry locations
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        $pwshInstalled = $null
        foreach ($path in $uninstallPaths) {
            $pwshInstalled = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
                            Where-Object { $_.DisplayName -like "PowerShell 7*" }
            if ($pwshInstalled) { break }
        }
        
        if ($pwshInstalled) {
            $displayName = $pwshInstalled.DisplayName
            $version = $pwshInstalled.DisplayVersion
            $uninstallString = $pwshInstalled.UninstallString
            
            Write-Log "Found existing installation: $displayName (Version: $version)" -Level INFO
            Write-Log "Uninstall string: $uninstallString" -Level INFO
            
            if ($uninstallString) {
                Write-Log "Uninstalling $displayName..."
                
                # Check if it's an MSI uninstall
                if ($uninstallString -match "MsiExec\.exe") {
                    # Extract product code
                    if ($uninstallString -match "\{([A-F0-9\-]+)\}") {
                        $productCode = $matches[1]
                        Write-Log "Product Code: $productCode" -Level INFO
                        
                        # Uninstall using msiexec
                        $uninstallArgs = "/x {$productCode} /quiet /norestart /l*v `"$LogDir\PowerShell7_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log`""
                        Write-Log "Executing: msiexec.exe $uninstallArgs"
                        
                        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -Wait -PassThru -ErrorAction Stop
                        
                        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 1605 -or $process.ExitCode -eq 3010) {
                            # 0 = success, 1605 = not installed, 3010 = success but restart required
                            Write-Log "Successfully uninstalled $displayName (Exit Code: $($process.ExitCode))" -Level SUCCESS
                        }
                        else {
                            Write-Log "Uninstall completed with exit code: $($process.ExitCode)" -Level WARNING
                        }
                    }
                }
                else {
                    # Try direct uninstall string
                    Write-Log "Attempting direct uninstall..."
                    if ($uninstallString -match '"([^"]+)"') {
                        $uninstaller = $matches[1]
                        Start-Process -FilePath $uninstaller -ArgumentList "/quiet /norestart" -Wait -ErrorAction Stop
                    }
                    else {
                        Start-Process -FilePath $uninstallString -ArgumentList "/quiet /norestart" -Wait -ErrorAction Stop
                    }
                    Write-Log "Successfully uninstalled $displayName" -Level SUCCESS
                }
                
                # Wait for uninstaller to complete cleanup
                Start-Sleep -Seconds 3
                
                # Verify removal
                $pwshPath = "${env:ProgramFiles}\PowerShell\7"
                if (Test-Path $pwshPath) {
                    Write-Log "Installation directory still exists, attempting manual cleanup..." -Level WARNING
                    try {
                        Remove-Item -Path $pwshPath -Recurse -Force -ErrorAction Stop
                        Write-Log "Manually removed installation directory" -Level SUCCESS
                    }
                    catch {
                        Write-Log "Could not remove installation directory: $_" -Level WARNING
                        Write-Log "Continuing with installation anyway..." -Level INFO
                    }
                }
            }
            else {
                Write-Log "No uninstall string found for $displayName" -Level WARNING
            }
        }
        else {
            Write-Log "No existing PowerShell 7 MSI installation found" -Level INFO
        }
    }
    catch {
        Write-Log "Error during uninstallation: $_" -Level WARNING
        Write-Log "Continuing with installation..." -Level INFO
    }
}

# Function to check if winget is available
function Test-WingetAvailable {
    try {
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-Log "winget is available at: $($wingetCmd.Source)" -Level SUCCESS
            
            # Test winget functionality
            $null = winget --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        }
        return $false
    }
    catch {
        return $false
    }
}

# Function to install PowerShell 7 using winget
function Install-PowerShell7Winget {
    Write-Log "Installing PowerShell 7 using winget..."
    
    try {
        # Prepare winget command
        $wingetArgs = @(
            "install"
            "--id", "Microsoft.PowerShell"
            "--source", "winget"
            "--silent"
            "--accept-package-agreements"
            "--accept-source-agreements"
            "--override", "/quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1"
        )
        
        Write-Log "Executing: winget $($wingetArgs -join ' ')"
        
        # Execute winget
        $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
        
        if ($process.ExitCode -eq 0) {
            Write-Log "PowerShell 7 installed successfully via winget!" -Level SUCCESS
            return $true
        }
        else {
            Write-Log "winget installation failed with exit code: $($process.ExitCode)" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "Failed to install via winget: $_" -Level ERROR
        return $false
    }
}

# Function to verify PowerShell 7 installation
function Test-PowerShell7Installation {
    Write-Log "Verifying PowerShell 7 installation..."
    
    $pwsh7Path = "${env:ProgramFiles}\PowerShell\7\pwsh.exe"
    
    if (Test-Path $pwsh7Path) {
        try {
            # Get version
            $versionOutput = & $pwsh7Path -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>&1
            Write-Log "PowerShell 7 installed successfully!" -Level SUCCESS
            Write-Log "Version: $versionOutput" -Level SUCCESS
            Write-Log "Location: $pwsh7Path" -Level INFO
            
            # Check if it's in PATH
            $pathEnv = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($pathEnv -like "*PowerShell\7*") {
                Write-Log "PowerShell 7 is in system PATH" -Level SUCCESS
            }
            else {
                Write-Log "PowerShell 7 is NOT in system PATH (may require logout/login)" -Level WARNING
            }
            
            return $true
        }
        catch {
            Write-Log "PowerShell 7 executable found but failed to run: $_" -Level ERROR
            return $false
        }
    }
    else {
        Write-Log "PowerShell 7 executable not found at expected location: $pwsh7Path" -Level ERROR
        return $false
    }
}

# Main script execution
Write-Log "========================================" -Level INFO
Write-Log "PowerShell 7 Clean Installation Script" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Current PowerShell Version: $($PSVersionTable.PSVersion)" -Level INFO
Write-Log "Operating System: $([System.Environment]::OSVersion.VersionString)" -Level INFO
Write-Log ""

# Step 1: Uninstall existing PowerShell 7 MSI
Write-Log "STEP 1: Removing existing PowerShell 7 installation (if present)" -Level INFO
Uninstall-PowerShell7MSI

# Step 2: Check winget availability
Write-Log ""
Write-Log "STEP 2: Checking winget availability" -Level INFO
$wingetAvailable = Test-WingetAvailable

if (-not $wingetAvailable) {
    Write-Log "winget is not available on this system" -Level ERROR
    Write-Log "Installing App Installer (which includes winget)..." -Level INFO
    
    try {
        # Try to install App Installer from Microsoft Store
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
        Start-Sleep -Seconds 5
        
        $wingetAvailable = Test-WingetAvailable
        
        if (-not $wingetAvailable) {
            throw "winget still not available after installing App Installer"
        }
    }
    catch {
        Write-Log "Failed to install winget: $_" -Level ERROR
        Write-Log "Please install App Installer manually from Microsoft Store" -Level ERROR
        Write-Log "Or download from: https://aka.ms/getwinget" -Level INFO
        exit 1
    }
}

# Step 3: Install PowerShell 7 using winget
Write-Log ""
Write-Log "STEP 3: Installing PowerShell 7 via winget" -Level INFO
$installSuccess = Install-PowerShell7Winget

if (-not $installSuccess) {
    Write-Log "Installation failed!" -Level ERROR
    exit 1
}

# Step 4: Verify installation
Write-Log ""
Write-Log "STEP 4: Verifying installation" -Level INFO
$verifySuccess = Test-PowerShell7Installation

# Final summary
Write-Log ""
Write-Log "========================================" -Level INFO
Write-Log "Installation Summary" -Level INFO
Write-Log "========================================" -Level INFO

if ($verifySuccess) {
    Write-Log "PowerShell 7 installation completed successfully!" -Level SUCCESS
    Write-Log "Log file: $LogFile" -Level INFO
    Write-Log ""
    Write-Log "NEXT STEPS:" -Level INFO
    Write-Log "1. You may need to restart your terminal or log out/in for PATH changes" -Level INFO
    Write-Log "2. Launch PowerShell 7 by typing 'pwsh' in any command prompt" -Level INFO
    Write-Log "3. Or search for 'PowerShell 7' in the Start menu" -Level INFO
    exit 0
}
else {
    Write-Log "PowerShell 7 installation verification failed!" -Level ERROR
    Write-Log "Log file: $LogFile" -Level INFO
    Write-Log "Please check the logs for details" -Level ERROR
    exit 1
}
