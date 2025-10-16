<#
.SYNOPSIS
    Install complete EmComm software suite
    
.DESCRIPTION
    Installs all emergency communications software with optional pre-configuration:
    - W1HKJ Suite (fldigi, flrig, flmsg, etc.)
    - VARA HF/FM modems
    - Winlink Express
    - Direwolf software TNC
    - YAAC APRS client
    - EchoLink VoIP
    - JS8Call weak signal
    - CHIRP radio programming
    - DMRconfig command-line tool
    - Anytone D878/D578 CPS
    
.PARAMETER ConfigFile
    JSON configuration file with operator settings, station config, and secrets.
    This file is gitignored and contains license keys and passwords.
    Copy EmComm-Config.template.json to EmComm-Config.json and customize.
    
.PARAMETER IncludeW1HKJ
    Install W1HKJ suite (default: true)
    
.PARAMETER IncludeVARA
    Install VARA modems (default: true)
    
.PARAMETER IncludeVARAFM
    Install VARA FM in addition to VARA HF (license key from config file)
    Edit EmComm-Config.json and set vara.fm.licenseKey
    
.PARAMETER IncludeWinlink
    Install Winlink Express (default: true)
    
.PARAMETER IncludeDirewolf
    Install Direwolf software TNC (default: true)
    
.PARAMETER IncludeYAAC
    Install YAAC APRS client (default: true)
    
.PARAMETER IncludeEchoLink
    Install EchoLink VoIP (default: true)
    
.PARAMETER IncludeJS8Call
    Install JS8Call (default: true)
    
.PARAMETER IncludeCHIRP
    Install CHIRP radio programming (default: true)
    
.PARAMETER IncludeDMRconfig
    Install DMRconfig command-line tool (default: false)
    
.PARAMETER IncludeAnytoneD878CPS
    Install Anytone AT-D878UV CPS (default: false)
    
.PARAMETER IncludeAnytoneD578CPS
    Install Anytone AT-D578UV CPS (default: false)
    
.PARAMETER W1HKJConfigPackage
    W1HKJ configuration package: EmComm, ARES, PublicService, Minimal, All
    
.EXAMPLE
    .\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json"
    Install all default EmComm software with pre-configuration
    
.EXAMPLE
    .\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json" -W1HKJConfigPackage EmComm -IncludeVARAFM
    Full installation with VARA FM (license from config file)
    
.EXAMPLE
    .\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json" -IncludeAnytoneD878CPS -IncludeAnytoneD578CPS
    Install with Anytone programming software
    
.NOTES
    Requires Administrator privileges
    Logs to C:\Logs\EmCommSuite_Install_YYYYMMDD_HHMMSS.log
    Run time: 20-40 minutes depending on selections
    
    AUTO-DETECTION FEATURES:
    - COM ports automatically detected if device="auto" in config
    - GPS location used if locator="auto" in config (enables Location Services automatically)
    - All secrets (license keys, passwords) in single gitignored config file

.INTUNE WIN32 APP DEPLOYMENT
    Install command: powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-EmCommSuite.ps1" -ConfigFile "EmComm-Config.json" -W1HKJConfigPackage EmComm
    Install behavior: System context
    Detection: Multiple - see individual scripts
    Return codes: 0=success, 1=failure
#>

# Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeW1HKJ,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeVARA,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeVARAFM,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeWinlink,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDirewolf,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeYAAC,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeEchoLink,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeJS8Call,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeCHIRP,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDMRconfig,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeAnytoneD878CPS,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeAnytoneD578CPS,
    
    [ValidateSet('EmComm','ARES','PublicService','Minimal','All')]
    [string]$W1HKJConfigPackage = 'EmComm'
)

# Set default values for include switches if not specified
if (-not $PSBoundParameters.ContainsKey('IncludeW1HKJ')) { $IncludeW1HKJ = $true }
if (-not $PSBoundParameters.ContainsKey('IncludeVARA')) { $IncludeVARA = $true }
if (-not $PSBoundParameters.ContainsKey('IncludeWinlink')) { $IncludeWinlink = $true }
if (-not $PSBoundParameters.ContainsKey('IncludeDirewolf')) { $IncludeDirewolf = $true }
if (-not $PSBoundParameters.ContainsKey('IncludeYAAC')) { $IncludeYAAC = $true }
if (-not $PSBoundParameters.ContainsKey('IncludeEchoLink')) { $IncludeEchoLink = $true }
if (-not $PSBoundParameters.ContainsKey('IncludeJS8Call')) { $IncludeJS8Call = $true }
if (-not $PSBoundParameters.ContainsKey('IncludeCHIRP')) { $IncludeCHIRP = $true }

# Import ConfigHelper module
$ModulePath = Join-Path $PSScriptRoot "Modules\EmComm-ConfigHelper.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
    Write-Host "Loaded ConfigHelper module with auto-detection features" -ForegroundColor Green
} else {
    Write-Host "WARNING: ConfigHelper module not found at $ModulePath - auto-detection disabled" -ForegroundColor Yellow
}

# Logging setup
$LogDir = "C:\Logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\EmCommSuite_Install_$Timestamp.log"

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

function Invoke-InstallScript {
    param(
        [string]$ScriptName,
        [string]$Arguments = "",
        [string]$Description
    )
    
    Write-Log "========================================"
    Write-Log "Installing: $Description"
    Write-Log "Script: $ScriptName"
    
    $ScriptPath = Join-Path $PSScriptRoot $ScriptName
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Log "Script not found: $ScriptPath" -Level ERROR
        return $false
    }
    
    try {
        if ($Arguments) {
            & $ScriptPath @ArgumentsList
        } else {
            & $ScriptPath
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "$Description installed successfully"
            return $true
        } else {
            Write-Log "$Description installation failed with exit code: $LASTEXITCODE" -Level WARNING
            return $false
        }
    }
    catch {
        Write-Log "$Description installation failed: $_" -Level ERROR
        return $false
    }
}

Write-Log "========================================"
Write-Log "EmComm Suite Installation Starting"
Write-Log "========================================"
Write-Log "Configuration file: $ConfigFile"
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Initialize configuration with auto-detection
if (Get-Command Initialize-EmCommConfig -ErrorAction SilentlyContinue) {
    Write-Log "Initializing configuration with auto-detection..."
    $Config = Initialize-EmCommConfig -ConfigFile $ConfigFile
    
    if (-not $Config) {
        Write-Log "Configuration initialization failed - check config file format" -Level ERROR
        exit 1
    }
    
    # Log auto-detection results
    if ($Config.rig.device -ne "auto" -and $Config.rig.device) {
        Write-Log "Auto-detected COM port: $($Config.rig.device)"
    }
    if ($Config.operator.locator -and $Config.operator.locator -ne "auto") {
        Write-Log "Grid square: $($Config.operator.locator)"
    }
} else {
    Write-Log "ConfigHelper module not available - using basic configuration loading" -Level WARNING
    
    # Fallback: Basic config file validation
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Configuration file not found: $ConfigFile" -Level ERROR
        exit 1
    }
    
    try {
        $Config = Get-Content $ConfigFile | ConvertFrom-Json
    }
    catch {
        Write-Log "Failed to parse configuration file: $_" -Level ERROR
        exit 1
    }
}

# Track installation results
$Results = @{}

# Install PowerShell 7 if needed
Write-Log "Checking PowerShell version"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Log "PowerShell 7+ required, installing..."
    $Results['PowerShell7'] = Invoke-InstallScript -ScriptName "Install-PowerShell7.ps1" -Description "PowerShell 7"
} else {
    Write-Log "PowerShell $($PSVersionTable.PSVersion) already installed"
    $Results['PowerShell7'] = $true
}

# Install W1HKJ Suite
if ($IncludeW1HKJ) {
    $Results['W1HKJ'] = Invoke-InstallScript -ScriptName "Install-W1HKJSuite.ps1" -Arguments "-ConfigFile `"$ConfigFile`" -ConfigPackage $W1HKJConfigPackage" -Description "W1HKJ Suite"
}

# Install VARA Modems
if ($IncludeVARA) {
    $VARAArgs = "-ConfigFile `"$ConfigFile`""
    if ($IncludeVARAFM) {
        $VARAArgs += " -IncludeFM"
    }
    $Results['VARA'] = Invoke-InstallScript -ScriptName "Install-VARAModem.ps1" -Arguments $VARAArgs -Description "VARA Modems"
}

# Install Winlink Express
if ($IncludeWinlink) {
    $Results['Winlink'] = Invoke-InstallScript -ScriptName "Install-Winlink.ps1" -Description "Winlink Express"
}

# Install Direwolf
if ($IncludeDirewolf) {
    $Results['Direwolf'] = Invoke-InstallScript -ScriptName "Install-Direwolf.ps1" -Arguments "-ConfigFile `"$ConfigFile`"" -Description "Direwolf Software TNC"
}

# Install YAAC
if ($IncludeYAAC) {
    $Results['YAAC'] = Invoke-InstallScript -ScriptName "Install-YAAC.ps1" -Arguments "-ConfigFile `"$ConfigFile`"" -Description "YAAC APRS Client"
}

# Install EchoLink
if ($IncludeEchoLink) {
    $Results['EchoLink'] = Invoke-InstallScript -ScriptName "Install-EchoLink.ps1" -Arguments "-ConfigFile `"$ConfigFile`"" -Description "EchoLink VoIP"
}

# Install JS8Call
if ($IncludeJS8Call) {
    $Results['JS8Call'] = Invoke-InstallScript -ScriptName "Install-JS8Call.ps1" -Arguments "-ConfigFile `"$ConfigFile`"" -Description "JS8Call"
}

# Install CHIRP
if ($IncludeCHIRP) {
    $Results['CHIRP'] = Invoke-InstallScript -ScriptName "Install-CHIRP.ps1" -Arguments "-ConfigFile `"$ConfigFile`"" -Description "CHIRP Radio Programming"
}

# Install DMRconfig
if ($IncludeDMRconfig) {
    $Results['DMRconfig'] = Invoke-InstallScript -ScriptName "Install-DMRconfig.ps1" -Arguments "-ConfigFile `"$ConfigFile`"" -Description "DMRconfig CLI Tool"
}

# Install Anytone D878 CPS
if ($IncludeAnytoneD878CPS) {
    $Results['AnytoneD878CPS'] = Invoke-InstallScript -ScriptName "Install-AnytoneD878CPS.ps1" -Arguments "-ConfigFile `"$ConfigFile`"" -Description "Anytone AT-D878UV CPS"
}

# Install Anytone D578 CPS
if ($IncludeAnytoneD578CPS) {
    $Results['AnytoneD578CPS'] = Invoke-InstallScript -ScriptName "Install-AnytoneD578CPS.ps1" -Arguments "-ConfigFile `"$ConfigFile`"" -Description "Anytone AT-D578UV CPS"
}

# Generate summary report
Write-Log "========================================"
Write-Log "Installation Summary"
Write-Log "========================================"

$TotalInstalls = $Results.Count
$SuccessfulInstalls = ($Results.Values | Where-Object { $_ -eq $true }).Count
$FailedInstalls = $TotalInstalls - $SuccessfulInstalls

foreach ($App in $Results.Keys | Sort-Object) {
    $Status = if ($Results[$App]) { "SUCCESS" } else { "FAILED" }
    Write-Log "  $App : $Status"
}

Write-Log "========================================"
Write-Log "Total: $TotalInstalls | Success: $SuccessfulInstalls | Failed: $FailedInstalls"
Write-Log "========================================"

if ($FailedInstalls -gt 0) {
    Write-Log "Some installations failed - check logs in $LogDir" -Level WARNING
    exit 1
} else {
    Write-Log "All installations completed successfully!"
    exit 0
}
