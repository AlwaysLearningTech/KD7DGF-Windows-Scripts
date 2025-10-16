<#
.SYNOPSIS
    Install W1HKJ Software Suite
    
.DESCRIPTION
    Automatically discovers and installs the latest versions of W1HKJ software suite.
    Optionally deploys configuration if ConfigPackage and ConfigFile are specified.
    
.PARAMETER ConfigPackage
    Optional: Configuration package to deploy (EmComm, ARES, PublicService, Minimal, All)
    If specified, ConfigFile must also be provided
    
.PARAMETER ConfigFile
    Optional: Path to JSON configuration file
    Required if ConfigPackage is specified
    
.EXAMPLE
    .\Install-W1HKJSuite.ps1
    Installs W1HKJ suite only, no configuration deployment
    
.EXAMPLE
    .\Install-W1HKJSuite.ps1 -ConfigPackage EmComm -ConfigFile "MyStation.json"
    Installs W1HKJ suite and deploys EmComm configuration
    
.NOTES
    Version: 2.0
    Requires: PowerShell 7+ and Administrator privileges
    Logs to C:\Logs\W1HKJ_Installer_YYYYMMDD_HHMMSS.log
    
.INTUNE WIN32 APP DEPLOYMENT
    Install command (software only):
        powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "Install-W1HKJSuite.ps1"
    
    Install command (with configuration):
        powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "Install-W1HKJSuite.ps1" -ConfigPackage EmComm -ConfigFile "W1HKJ-Config.json"
    
    Install behavior: System context
    Detection: File exists C:\Program Files (x86)\fldigi\fldigi.exe
    Return codes: 0=success, 1=failure
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('EmComm', 'ARES', 'PublicService', 'All', 'Minimal')]
    [string]$ConfigPackage = '',
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = ''
)
            Path: C:\Program Files (x86)\fldigi
            File: fldigi.exe
            Detection method: File or folder exists
        
        Alternative Detection - Registry (individual app):
            Path: HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*
            Value: DisplayName
            Type: String
            Operator: Contains
            Value data: fldigi
    
    Return Codes:
        0    = Success - All applications installed
        1    = Failed - One or more installations failed
        3010 = Success (restart recommended but not required)
    
    Dependencies:
        PowerShell 7+ (script will auto-install if missing)
        Internet connectivity to https://www.w1hkj.org/files/
        Optional: winget (for PowerShell 7 installation if needed)
    
    Supersedence:
        Can supersede older versions of W1HKJ application suites
        Recommend creating version-specific deployments for tracking
    
    Assignments:
        Recommended for: Amateur Radio / EmComm device groups
        Install time: Allow 15-30 minutes depending on network speed
        User context: System (required for all applications)
        Restart required: No
    
    Monitoring:
        Log location: C:\Logs\W1HKJ_Installer_[timestamp].log
        Check logs for detailed installation status of each application
        Script reports success/failure counts in final summary
    
    Notes:
        - Script dynamically discovers latest versions from W1HKJ website
        - Automatically uninstalls old versions before installing new ones
        - All 15 applications installed in sequence to avoid conflicts
        - Progress logged to C:\Logs\ directory
        - Can be re-run safely for updates
#>

#Requires -RunAsAdministrator

# Function to install PowerShell 7 and relaunch script
function Install-PowerShell7 {
    param(
        [string]$ScriptPath
    )
    
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "PowerShell 7 Required" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "This script requires PowerShell 7+ for optimal performance." -ForegroundColor Cyan
    Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installing PowerShell 7..." -ForegroundColor Green
    
    try {
        # Download and install PowerShell 7 using winget (fastest method)
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Using winget to install PowerShell..." -ForegroundColor Cyan
            winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        }
        else {
            # Fallback: Download MSI installer
            Write-Host "Downloading PowerShell 7 installer..." -ForegroundColor Cyan
            $msiUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
            $msiPath = "$env:TEMP\PowerShell-7-win-x64.msi"
            
            Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
            
            Write-Host "Installing PowerShell 7..." -ForegroundColor Cyan
            Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1" -Wait
            
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "PowerShell 7 installed successfully!" -ForegroundColor Green
        Write-Host "Relaunching script in PowerShell 7..." -ForegroundColor Cyan
        Write-Host ""
        
        # Find PowerShell 7 executable
        $pwsh7Path = "${env:ProgramFiles}\PowerShell\7\pwsh.exe"
        
        if (Test-Path $pwsh7Path) {
            # Relaunch this script in PowerShell 7
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
            Start-Process -FilePath $pwsh7Path -ArgumentList $arguments -Wait -NoNewWindow
            
            # Exit the PowerShell 5 instance
            exit 0
        }
        else {
            Write-Error "PowerShell 7 installation completed but pwsh.exe not found. Please restart your terminal and run the script again."
            exit 1
        }
    }
    catch {
        Write-Error "Failed to install PowerShell 7: $_"
        Write-Host "Please install PowerShell 7 manually from: https://aka.ms/powershell-release?tag=stable" -ForegroundColor Yellow
        exit 1
    }
}

# Check PowerShell version and auto-upgrade if needed
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Install-PowerShell7 -ScriptPath $PSCommandPath
}

# Initialize logging
$LogDir = "C:\Logs"
$LogFile = Join-Path $LogDir "W1HKJ_Installer_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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

# Function to get latest version from W1HKJ directory
function Get-LatestVersion {
    param(
        [string]$BaseUrl,
        [string]$AppName,
        [string]$SubDir = ""
    )
    
    try {
        $url = if ($SubDir) { "$BaseUrl$SubDir/" } else { "$BaseUrl$AppName/" }
        Write-Log "Checking for latest version at: $url"
        
        # PowerShell 7+ parameters
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -SkipHttpErrorCheck:$false -ErrorAction Stop
        
        # Parse HTML to find _setup.exe files
        $pattern = "($AppName-[\d\.]+_setup\.exe)"
        $regexMatches = [regex]::Matches($response.Content, $pattern)
        
        if ($regexMatches.Count -eq 0) {
            Write-Log "No installer found for $AppName" -Level WARNING
            return $null
        }
        
        # Sort versions and get the latest (assumes semantic versioning)
        $versions = $regexMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        
        # Get the file with highest version number using PowerShell 7+ features
        $latest = $versions | Sort-Object {
            # PowerShell 7+ error handling
            try {
                [version]($_ -replace "$AppName-" -replace "_setup\.exe" -replace "[^\d\.].*$")
            }
            catch {
                # Fallback for malformed version strings
                [version]"0.0.0"
            }
        } -Descending | Select-Object -First 1        Write-Log "Found latest version: $latest" -Level SUCCESS
        
        return @{
            FileName = $latest
            FullPath = if ($SubDir) { "$SubDir/$latest" } else { "$AppName/$latest" }
            Version = ($latest -replace "$AppName-" -replace "_setup\.exe")
        }
    }
    catch {
        Write-Log "Failed to get latest version for $AppName : $_" -Level ERROR
        return $null
    }
}

# Function to uninstall existing version
function Uninstall-ExistingVersion {
    param(
        [string]$AppName
    )
    
    try {
        Write-Log "Checking for existing installation of $AppName..."
        
        # Check both 64-bit and 32-bit registry locations
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        $installed = $null
        foreach ($path in $uninstallPaths) {
            $installed = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
                         Where-Object { $_.DisplayName -like "$AppName*" }
            if ($installed) { break }
        }
        
        if ($installed) {
            $displayName = $installed.DisplayName
            $version = $installed.DisplayVersion
            $uninstallString = $installed.UninstallString
            
            Write-Log "Found existing installation: $displayName (Version: $version)" -Level INFO
            
            if ($uninstallString) {
                Write-Log "Uninstalling $displayName..."
                
                # Parse uninstall string
                if ($uninstallString -match '"([^"]+)"') {
                    $uninstaller = $matches[1]
                    Start-Process -FilePath $uninstaller -ArgumentList "/SILENT" -Wait -ErrorAction Stop
                    Write-Log "Successfully uninstalled $displayName" -Level SUCCESS
                }
                else {
                    Start-Process -FilePath $uninstallString -ArgumentList "/SILENT" -Wait -ErrorAction Stop
                    Write-Log "Successfully uninstalled $displayName" -Level SUCCESS
                }
                
                # Wait a moment for uninstaller to complete cleanup
                Start-Sleep -Seconds 2
            }
            else {
                Write-Log "No uninstall string found for $displayName" -Level WARNING
            }
        }
        else {
            Write-Log "No existing installation found for $AppName"
        }
    }
    catch {
        Write-Log "Error during uninstallation of $AppName : $_" -Level WARNING
    }
}

# Main script execution
Write-Log "========================================" -Level INFO
Write-Log "W1HKJ Software Auto-Installer Starting" -Level INFO
Write-Log "========================================" -Level INFO

$DownloadRoot = "https://www.w1hkj.org/files/"
$TempDir = "$env:TEMP\W1HKJ_Installers"

# Create temp directory
try {
    if (-not (Test-Path $TempDir)) {
        New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
        Write-Log "Created temporary directory: $TempDir"
    }
}
catch {
    Write-Log "Failed to create temporary directory: $_" -Level ERROR
    exit 1
}

# Define software packages - now just app names, versions discovered dynamically
$SoftwareList = @(
    @{ Name = "fldigi";     SubDir = "" },
    @{ Name = "flrig";      SubDir = "" },
    @{ Name = "flmsg";      SubDir = "" },
    @{ Name = "flamp";      SubDir = "" },
    @{ Name = "fllog";      SubDir = "" },
    @{ Name = "flnet";      SubDir = "" },
    @{ Name = "flwkey";     SubDir = "" },
    @{ Name = "flwrap";     SubDir = "" },
    @{ Name = "flcluster";  SubDir = "" },
    @{ Name = "flaa";       SubDir = "" },
    @{ Name = "nanoIO";     SubDir = "" },
    @{ Name = "kcat";       SubDir = "" },
    @{ Name = "comptext";   SubDir = "test_suite" },
    @{ Name = "comptty";    SubDir = "test_suite" },
    @{ Name = "linsim";     SubDir = "test_suite" }
)

$successCount = 0
$failureCount = 0

# Sequential processing to avoid installer conflicts
# Note: PowerShell 7+ supports ForEach-Object -Parallel for future optimization
foreach ($app in $SoftwareList) {
    Write-Log "========================================" -Level INFO
    Write-Log "Processing: $($app.Name)" -Level INFO
    
    # Get latest version info
    $versionInfo = Get-LatestVersion -BaseUrl $DownloadRoot -AppName $app.Name -SubDir $app.SubDir
    
    if (-not $versionInfo) {
        Write-Log "Skipping $($app.Name) - could not determine latest version" -Level WARNING
        $failureCount++
        continue
    }
    
    $url = "$DownloadRoot$($versionInfo.FullPath)"
    $dest = Join-Path $TempDir $versionInfo.FileName
    
    try {
        # Download installer
        Write-Log "Downloading $($app.Name) version $($versionInfo.Version)..."
        
        # PowerShell 7+: Disable progress bar for faster downloads (10-50% faster)
        $ProgressPreference = 'SilentlyContinue'
        
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        
        # Restore progress preference
        $ProgressPreference = 'Continue'
        
        Write-Log "Downloaded successfully to: $dest" -Level SUCCESS
        
        # Verify download
        if (-not (Test-Path $dest)) {
            throw "Downloaded file not found at $dest"
        }
        
        $fileSize = (Get-Item $dest).Length / 1MB
        Write-Log "File size: $([math]::Round($fileSize, 2)) MB"
        
        # Uninstall existing version
        Uninstall-ExistingVersion -AppName $app.Name
        
        # Install new version
        Write-Log "Installing $($app.Name) version $($versionInfo.Version)..."
        $process = Start-Process -FilePath $dest -ArgumentList "/SILENT" -Wait -PassThru -ErrorAction Stop
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Successfully installed $($app.Name) version $($versionInfo.Version)" -Level SUCCESS
            $successCount++
        }
        else {
            Write-Log "Installation completed with exit code: $($process.ExitCode)" -Level WARNING
            $successCount++
        }
        
        # Clean up installer
        Remove-Item -Path $dest -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Failed to download or install $($app.Name): $_" -Level ERROR
        $failureCount++
    }
}

# Cleanup temp directory
try {
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Cleaned up temporary directory"
    }
}
catch {
    Write-Log "Failed to clean up temporary directory: $_" -Level WARNING
}

# Final summary
Write-Log "========================================" -Level INFO
Write-Log "Installation Summary" -Level INFO
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level INFO
Write-Log "Successful: $successCount" -Level SUCCESS
Write-Log "Failed: $failureCount" -Level $(if ($failureCount -eq 0) { 'SUCCESS' } else { 'WARNING' })
Write-Log "Log file: $LogFile" -Level INFO
Write-Log "========================================" -Level INFO

if ($failureCount -eq 0) {
    Write-Log "All W1HKJ software processed successfully!" -Level SUCCESS
    exit 0
}
else {
    Write-Log "Some installations failed. Check log for details." -Level WARNING
    exit 1
}
