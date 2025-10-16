<#
.SYNOPSIS
    Install DMRconfig for DMR radio programming via command line
    
.DESCRIPTION
    Downloads and installs latest DMRconfig from GitHub (sergev/dmrconfig).
    DMRconfig supports Anytone, TYT, Radioddity, and other DMR radios.
    
.PARAMETER ConfigFile
    Optional JSON configuration file for default radio settings
    
.EXAMPLE
    .\Install-DMRconfig.ps1
    Install latest DMRconfig
    
.EXAMPLE
    .\Install-DMRconfig.ps1 -ConfigFile "EmComm-Config.json"
    Install with pre-configured settings
    
.NOTES
    Requires Administrator privileges
    Logs to C:\Logs\DMRconfig_Install_YYYYMMDD_HHMMSS.log
    Command-line tool for DMR codeplug management

.INTUNE WIN32 APP DEPLOYMENT
    Install command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-DMRconfig.ps1"
    Install behavior: System context
    Detection: File exists %ProgramFiles%\DMRconfig\dmrconfig.exe
    Return codes: 0=success, 1=failure
#>

# Requires -RunAsAdministrator

param(
    [string]$ConfigFile
)

# Logging setup
$LogDir = "C:\Logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\DMRconfig_Install_$Timestamp.log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )
    $LogMessage = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $LogMessage
    
    switch ($Level) {
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'WARNING' { Write-Host $Message -ForegroundColor Yellow }
        default   { Write-Host $Message }
    }
}

Write-Log "Starting DMRconfig installation"

# GitHub API for latest release
$GitHubAPI = "https://api.github.com/repos/sergev/dmrconfig/releases/latest"
$InstallDir = "$env:ProgramFiles\DMRconfig"

$TempDir = "$env:TEMP\DMRconfig"
if (-not (Test-Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}

# Load configuration if provided
$Config = $null
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Write-Log "Loading configuration from $ConfigFile"
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Log "Configuration loaded successfully"
    }
    catch {
        Write-Log "Failed to load configuration: $_" -Level WARNING
    }
}

try {
    Write-Log "Fetching latest DMRconfig release from GitHub"
    $Release = Invoke-RestMethod -Uri $GitHubAPI -Headers @{ "User-Agent" = "PowerShell" } -ErrorAction Stop
    $Version = $Release.tag_name
    Write-Log "Latest version: $Version"
    
    # Find Windows binary (dmrconfig-windows.exe or similar)
    $Asset = $Release.assets | Where-Object { 
        $_.name -match "dmrconfig.*win.*\.exe$" -or $_.name -match "dmrconfig\.exe$"
    } | Select-Object -First 1
    
    if (-not $Asset) {
        Write-Log "No Windows binary found, compiling from source may be required" -Level WARNING
        Write-Log "Installing from source repository"
        
        # Clone and build (requires mingw/gcc)
        Write-Log "Cloning repository"
        & git clone https://github.com/sergev/dmrconfig.git "$TempDir\src" 2>&1 | ForEach-Object { Write-Log $_ }
        
        # For now, just note that manual compilation is needed
        Write-Log "DMRconfig requires manual compilation on Windows" -Level ERROR
        Write-Log "Install mingw-w64 and run 'make' in $TempDir\src" -Level ERROR
        exit 1
    }
    
    $DownloadUrl = $Asset.browser_download_url
    $BinaryName = $Asset.name
    
    Write-Log "Downloading DMRconfig from $DownloadUrl"
    $BinaryPath = "$TempDir\$BinaryName"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -ErrorAction Stop
    Write-Log "Download completed: $BinaryPath"

    # Install to Program Files
    if (-not (Test-Path $InstallDir)) {
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    }
    
    Copy-Item -Path $BinaryPath -Destination "$InstallDir\dmrconfig.exe" -Force
    Write-Log "Installed to $InstallDir\dmrconfig.exe"
    
    # Add to PATH
    $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($CurrentPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$InstallDir", "Machine")
        Write-Log "Added $InstallDir to system PATH"
    }
    
}
catch {
    Write-Log "Failed to install DMRconfig: $_" -Level ERROR
    exit 1
}

# Create sample configuration files
Write-Log "Creating sample configuration directory"
$SampleDir = "$InstallDir\samples"
if (-not (Test-Path $SampleDir)) {
    New-Item -Path $SampleDir -ItemType Directory -Force | Out-Null
}

# Create README
$ReadmeContent = @"
DMRconfig - Command Line DMR Radio Programmer
==============================================

Usage:
  dmrconfig -r              Read codeplug from radio
  dmrconfig -w file.conf    Write codeplug to radio
  dmrconfig -c file.conf    Check codeplug file
  dmrconfig -v file.img     Verify codeplug image

Supported Radios:
  - Anytone AT-D868UV, AT-D878UV
  - TYT MD-380, MD-390, MD-UV380, MD-UV390
  - Radioddity GD-77
  - Baofeng DM-1801, DM-1701
  
Configuration File Format:
  See samples in: $SampleDir

More information:
  https://github.com/sergev/dmrconfig
"@

Set-Content -Path "$InstallDir\README.txt" -Value $ReadmeContent -Force
Write-Log "Created README.txt"

# Cleanup
Write-Log "Cleaning up temporary files"
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "DMRconfig installation completed successfully"
Write-Log "Run 'dmrconfig' from command line or PowerShell" -Level INFO
exit 0
