<#
.SYNOPSIS
    Deploy W1HKJ configuration from JSON template
    
.DESCRIPTION
    Creates fldigi configuration files and directory structure from JSON configuration.
    Called automatically by Install-W1HKJSuite.ps1 when ConfigPackage and ConfigFile parameters are provided.
    Can also be run standalone for configuration updates.
    
.PARAMETER ConfigPackage
    REQUIRED: Configuration package type (EmComm, ARES, PublicService, Minimal, All)
    
.PARAMETER ConfigFile
    Path to JSON configuration file (default: W1HKJ-Config.json)
    
.PARAMETER SkipBackup
    Skip backing up existing configuration
    
.EXAMPLE
    .\Set-W1HKJConfiguration.ps1 -ConfigPackage EmComm -ConfigFile "MyStation.json"
    
.NOTES
    Typically called by Install-W1HKJSuite.ps1, but can be run standalone for updates
    Logs to C:\Logs\W1HKJ_Config_YYYYMMDD_HHMMSS.log
#>[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('EmComm', 'ARES', 'PublicService', 'All', 'Minimal')]
    [string]$ConfigPackage,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = (Join-Path $PSScriptRoot "W1HKJ-Config.json"),
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBackup
)

# Initialize logging
$LogDir = "C:\Logs"
$LogFile = Join-Path $LogDir "W1HKJ_Config_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create log directory
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
    
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    
    switch ($Level) {
        'INFO'    { Write-Host $logMessage -ForegroundColor Cyan }
        'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logMessage -ForegroundColor Red }
        'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
    }
}

Write-Log "========================================" -Level INFO
Write-Log "W1HKJ Configuration Deployment Starting" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Package: $ConfigPackage" -Level INFO
Write-Log "Config File: $ConfigFile" -Level INFO

# Load configuration from JSON file
$config = $null
$UserCallsign = ""

if (-not (Test-Path $ConfigFile)) {
    Write-Log "Configuration file not found: $ConfigFile" -Level ERROR
    Write-Log "Please create W1HKJ-Config.json from W1HKJ-Config.template.json" -Level ERROR
    exit 1
}

try {
    Write-Log "Loading configuration from: $ConfigFile"
    $configContent = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
    $config = $configContent | ConvertFrom-Json -ErrorAction Stop
    Write-Log "Configuration loaded successfully" -Level SUCCESS
    
    # Get callsign from config - REQUIRED
    if (-not $config.operator.callsign -or $config.operator.callsign -eq "") {
        Write-Log "ERROR: operator.callsign is REQUIRED in $ConfigFile" -Level ERROR
        Write-Log "Please edit your configuration file and set a valid callsign" -Level ERROR
        exit 1
    }
    
    $UserCallsign = $config.operator.callsign
    Write-Log "Callsign from config: $UserCallsign" -Level SUCCESS
}
catch {
    Write-Log "Failed to load configuration file: $_" -Level ERROR
    Write-Log "Please verify JSON syntax with: Get-Content '$ConfigFile' | ConvertFrom-Json" -Level ERROR
    exit 1
}

# Configuration directories
$FldigiDir = Join-Path $env:USERPROFILE "fldigi.files"
$NbemsDir = Join-Path $env:USERPROFILE "NBEMS.files"

# Subdirectories
$Directories = @{
    'Fldigi'        = $FldigiDir
    'Logs'          = Join-Path $FldigiDir "logs"
    'Macros'        = Join-Path $FldigiDir "macros"
    'Images'        = Join-Path $FldigiDir "images"
    'Palettes'      = Join-Path $FldigiDir "palettes"
    'Scripts'       = Join-Path $FldigiDir "scripts"
    'Rigs'          = Join-Path $FldigiDir "rigs"
    'Temp'          = Join-Path $FldigiDir "temp"
    'NBEMS'         = $NbemsDir
    'ICS'           = Join-Path $NbemsDir "ICS"
    'ICSTemplates'  = Join-Path $NbemsDir "ICS\templates"
    'ICSMessages'   = Join-Path $NbemsDir "ICS\messages"
    'WRAP'          = Join-Path $NbemsDir "WRAP"
    'WRAPRecv'      = Join-Path $NbemsDir "WRAP\recv"
    'WRAPSend'      = Join-Path $NbemsDir "WRAP\send"
    'FLAMP'         = Join-Path $NbemsDir "FLAMP"
    'FLAMPrx'       = Join-Path $NbemsDir "FLAMP\rx"
    'FLAMPtx'       = Join-Path $NbemsDir "FLAMP\tx"
}

Write-Log "========================================" -Level INFO
Write-Log "W1HKJ Configuration Deployment Starting" -Level INFO
Write-Log "Package: $ConfigPackage" -Level INFO
Write-Log "========================================" -Level INFO

# Create directory structure
Write-Log "Creating directory structure..." -Level INFO
foreach ($dir in $Directories.Values) {
    try {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Write-Log "Created: $dir" -Level SUCCESS
        }
        else {
            Write-Log "Exists: $dir" -Level INFO
        }
    }
    catch {
        Write-Log "Failed to create $dir : $_" -Level ERROR
    }
}

# Backup existing configuration
if (-not $SkipBackup) {
    Write-Log "Backing up existing configuration..." -Level INFO
    $BackupDir = Join-Path $env:USERPROFILE "fldigi_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    if (Test-Path (Join-Path $FldigiDir "fldigi_def.xml")) {
        try {
            Copy-Item -Path $FldigiDir -Destination $BackupDir -Recurse -ErrorAction Stop
            Write-Log "Backup created: $BackupDir" -Level SUCCESS
        }
        catch {
            Write-Log "Backup failed: $_" -Level WARNING
        }
    }
}

# Create minimal fldigi_def.xml template
function New-FldigiConfig {
    param(
        [string]$Callsign = "NOCALL",
        [hashtable]$ConfigData = @{}
    )
    
    $xmlContent = @"
<?xml version="1.0"?>
<FLDIGI_DEFS>
  <!-- Operator Information -->
  <MYCALL>$Callsign</MYCALL>
  <MYNAME></MYNAME>
  <MYQTH></MYQTH>
  <MYLOCATOR></MYLOCATOR>
  <MYANTENNA></MYANTENNA>
  
  <!-- Audio Settings -->
  <AUDIOIO>1</AUDIOIO>
  <RXSAMPLERATE>48000</RXSAMPLERATE>
  <TXSAMPLERATE>48000</TXSAMPLERATE>
  <TXATTEN>-3.0</TXATTEN>
  
  <!-- Waterfall -->
  <WFHEIGHT>125</WFHEIGHT>
  <WFPREFILTER>1</WFPREFILTER>
  <PALETTENAME>default.pal</PALETTENAME>
  
  <!-- PTT -->
  <PTTMETHOD>0</PTTMETHOD>
  
  <!-- Rig Control -->
  <HAMRIGMODEL>0</HAMRIGMODEL>
  <HAMRIGDEVICE>COM1</HAMRIGDEVICE>
  <HAMRIGBAUDRATE>4</HAMRIGBAUDRATE>
  
  <!-- Logging -->
  <ADIF_LOG_FILENAME>logbook.adif</ADIF_LOG_FILENAME>
  <LOGSQLITEDBNAME>logbook.db</LOGSQLITEDBNAME>
  
  <!-- NBEMS Integration -->
  <FLMSG_PATHNAME>C:\Program Files (x86)\flmsg\flmsg.exe</FLMSG_PATHNAME>
  <OPEN_FLMSG>1</OPEN_FLMSG>
  
  <!-- FSQ Settings -->
  <FSQFREQLOCK>1</FSQFREQLOCK>
  <FSQSHOWMONITOR>1</FSQSHOWMONITOR>
  
  <!-- UI Settings -->
  <TOOLTIPS>1</TOOLTIPS>
  <CONFIRMEXIT>1</CONFIRMEXIT>
</FLDIGI_DEFS>
"@
    
    $configFile = Join-Path $FldigiDir "fldigi_def.xml"
    try {
        $xmlContent | Out-File -FilePath $configFile -Encoding UTF8
        Write-Log "Created fldigi_def.xml with callsign: $Callsign" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to create fldigi_def.xml: $_" -Level ERROR
        return $false
    }
}

# Create default macros for EmComm
function New-EmCommMacros {
    param(
        [string]$Callsign = "NOCALL",
        [string]$Package = "EmComm"
    )
    $macrosContent = @"
//fldigi macro definition file
// This file defines the macros for fldigi
//
// Macro file format:
// <MACROS>
// <MACRO>[tab number][button number]
// <NAME>macro name</NAME>
// <TEXT>macro text</TEXT>
// </MACRO>
// ...
// </MACROS>

<MACROS>
<MACRO>0 0
<NAME>CQ</NAME>
<TEXT>CQ CQ CQ DE <MYCALL> <MYCALL> <MYCALL> K</TEXT>
</MACRO>

<MACRO>0 1
<NAME>Quick QSO</NAME>
<TEXT><CALL> DE <MYCALL> = GE OM TNX FER CALL = NAME IS <MYNAME> <MYNAME> = QTH IS <MYQTH> <MYQTH> = HW? <CALL> DE <MYCALL> K</TEXT>
</MACRO>

<MACRO>0 2
<NAME>STATUS</NAME>
<TEXT>MY STATUS: <MYCALL> QRV <MODE> @ <FREQ> MHz</TEXT>
</MACRO>

<MACRO>0 3
<NAME>ICS213</NAME>
<TEXT><EXEC>/flmsg -show RADIO /flmsg -show ICS213</TEXT>
</MACRO>

<MACRO>1 0
<NAME>NET START</NAME>
<TEXT>THIS IS <MYCALL> CALLING THE EmComm NET = NET IS NOW OPEN FOR CHECK-INS = PLEASE SEND YOUR CALL FOLLOWED BY K</TEXT>
</MACRO>

<MACRO>1 1
<NAME>CHECKIN</NAME>
<TEXT>THIS IS <MYCALL> CHECKING IN TO THE NET K</TEXT>
</MACRO>

<MACRO>1 2
<NAME>RELAY</NAME>
<TEXT>RELAY FROM <MYCALL> = </TEXT>
</MACRO>

<MACRO>1 3
<NAME>TRAFFIC</NAME>
<TEXT>TRAFFIC FOR <CALL> FROM <MYCALL> = MESSAGE FOLLOWS = </TEXT>
</MACRO>
</MACROS>
"@
    
    $macrosFile = Join-Path $Directories['Macros'] "macros.mdf"
    try {
        $macrosContent | Out-File -FilePath $macrosFile -Encoding UTF8
        Write-Log "Created EmComm macros" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to create macros: $_" -Level ERROR
        return $false
    }
}

# Create default palette
function New-DefaultPalette {
    # Default waterfall palette (simple blue to red gradient)
    $paletteContent = @"
# Default Waterfall Palette
# R G B values 0-255
0 0 0
0 0 32
0 0 64
0 0 96
0 0 128
0 32 128
0 64 128
0 96 128
0 128 128
32 128 96
64 128 64
96 128 32
128 128 0
128 96 0
128 64 0
128 32 0
128 0 0
"@
    
    $paletteFile = Join-Path $Directories['Palettes'] "default.pal"
    try {
        $paletteContent | Out-File -FilePath $paletteFile -Encoding ASCII
        Write-Log "Created default palette" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to create palette: $_" -Level ERROR
        return $false
    }
}

# Deploy configuration based on package type
Write-Log "Deploying $ConfigPackage configuration..." -Level INFO

$success = $true

# Create base configuration
try {
    if (-not (New-FldigiConfig -Callsign $UserCallsign -ConfigData ($config -as [hashtable]))) {
        $success = $false
    }
}
catch {
    Write-Log "Failed to create fldigi configuration: $_" -Level ERROR
    $success = $false
}

# Deploy package-specific configurations
switch ($ConfigPackage) {
    'EmComm' {
        Write-Log "Deploying EmComm package with emergency macros..." -Level INFO
        try {
            if (-not (New-EmCommMacros -Callsign $UserCallsign -Package "EmComm")) { $success = $false }
        }
        catch {
            Write-Log "Failed to create EmComm macros: $_" -Level ERROR
            $success = $false
        }
    }
    'ARES' {
        Write-Log "Deploying ARES package..." -Level INFO
        try {
            if (-not (New-EmCommMacros -Callsign $UserCallsign -Package "ARES")) { $success = $false }
        }
        catch {
            Write-Log "Failed to create ARES macros: $_" -Level ERROR
            $success = $false
        }
    }
    'PublicService' {
        Write-Log "Deploying Public Service package..." -Level INFO
        try {
            if (-not (New-EmCommMacros -Callsign $UserCallsign -Package "PublicService")) { $success = $false }
        }
        catch {
            Write-Log "Failed to create PublicService macros: $_" -Level ERROR
            $success = $false
        }
    }
    'All' {
        Write-Log "Deploying complete package with all macros and forms..." -Level INFO
        try {
            if (-not (New-EmCommMacros -Callsign $UserCallsign -Package "All")) { $success = $false }
        }
        catch {
            Write-Log "Failed to create All package macros: $_" -Level ERROR
            $success = $false
        }
    }
    'Minimal' {
        Write-Log "Deploying minimal configuration..." -Level INFO
    }
}

# Create default palette
try {
    if (-not (New-DefaultPalette)) {
        Write-Log "Palette creation failed but continuing..." -Level WARNING
    }
}
catch {
    Write-Log "Error creating palette: $_" -Level WARNING
}

# Create README for user
$readmeContent = @"
W1HKJ Configuration Deployed
============================

Configuration Package: $ConfigPackage
Deployment Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Callsign: $UserCallsign

Directories Created:
- Configuration: $FldigiDir
- NBEMS Files: $NbemsDir

Next Steps:
1. Launch fldigi and verify your callsign and station information
2. Configure your audio devices in Configure > Sound Card
3. Set up rig control if applicable in Configure > Rig
4. Customize macros in Configure > Macros
5. Review ICS forms in flmsg

For help, visit: https://www.w1hkj.org/

Log file: $LogFile
"@

$readmeFile = Join-Path $FldigiDir "DEPLOYMENT_README.txt"
$readmeContent | Out-File -FilePath $readmeFile -Encoding UTF8

Write-Log "========================================" -Level INFO
Write-Log "Configuration Deployment Summary" -Level INFO
Write-Log "Package: $ConfigPackage" -Level INFO
Write-Log "Status: $(if ($success) { 'SUCCESS' } else { 'COMPLETED WITH WARNINGS' })" -Level $(if ($success) { 'SUCCESS' } else { 'WARNING' })
Write-Log "Configuration Directory: $FldigiDir" -Level INFO
Write-Log "NBEMS Directory: $NbemsDir" -Level INFO
Write-Log "README: $readmeFile" -Level INFO
Write-Log "Log file: $LogFile" -Level INFO
Write-Log "========================================" -Level INFO

if ($success) {
    Write-Log "Configuration deployment completed successfully!" -Level SUCCESS
    exit 0
}
else {
    Write-Log "Configuration deployment completed with warnings. Check log for details." -Level WARNING
    exit 0
}
