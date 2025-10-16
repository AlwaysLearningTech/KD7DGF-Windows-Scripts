# Copilot Instructions for KD7DGF Windows Scripts (EmComm Tools)

## CRITICAL RULES
1. **NO SUMMARY FILES** - Never create SUMMARY.md, IMPLEMENTATION_SUMMARY.md, or similar files. Report findings in chat only.
2. **UPDATE DOCUMENTATION IN-PLACE** - Modify existing README.md, QUICK_REFERENCE.md, and other docs directly.
3. **LOOK AT ACTUAL FILES FIRST** - Always read source files to verify method names, parameters, and return types before making changes.
4. **TEST BEFORE COMMITTING** - Validate all PowerShell scripts with `Test-Path`, `Get-Command`, and syntax checking.

## Project Overview
This is a PowerShell-based deployment system for emergency communications (EmComm) software on Windows:
- **Target Users**: Amateur radio operators, emergency coordinators, IT administrators
- **Deployment Method**: Microsoft Intune Win32 apps or standalone PowerShell execution
- **Software Managed**: W1HKJ Suite, VARA modems, Winlink, Direwolf, YAAC, EchoLink, JS8Call, CHIRP, DMRconfig, Anytone CPS
- **Key Features**: Auto-detection (COM ports, GPS location), unified configuration, automated installation

## PowerShell Best Practices

### File Naming Conventions
- **Approved Verbs**: Use `Get-`, `Set-`, `Install-`, `Remove-`, `Test-`, `New-`, etc.
- **PascalCase**: `Install-EmCommSuite.ps1`, `Get-AvailableComPorts.ps1`
- **Module Files**: `ModuleName.psm1` in `Modules/` directory
- **Configuration**: `Config.template.json` for templates, `Config.json` for actual (gitignored)

### Script Structure
```powershell
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER ParameterName
    Parameter description
.EXAMPLE
    Usage example
.NOTES
    Prerequisites, requirements, deployment info
#>

# Requires -RunAsAdministrator  # If admin needed

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigFile
)

# Script body
```

### Logging Standards
**ALL scripts must log to `C:\Logs\`:**

```powershell
$LogDir = "C:\Logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$LogFile = "$LogDir\${ScriptName}_$Timestamp.log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )
    $LogMessage = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $LogMessage
    
    switch ($Level) {
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'WARNING' { Write-Host $Message -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        default   { Write-Host $Message }
    }
}
```

### Error Handling
```powershell
try {
    # Operation
    Write-Log "Operation started" -Level INFO
}
catch {
    Write-Log "Operation failed: $_" -Level ERROR
    exit 1
}
finally {
    # Cleanup
}
```

### Exit Codes
- `0` = Success
- `1` = General failure
- `2` = Configuration error
- `3` = Prerequisite missing
- `4` = Download/network error

## Prerequisites Documentation

### For End Users (Include in Documentation)
```powershell
# 1. Set Execution Policy (one-time, run as admin)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2. Verify PowerShell version (5.1+ required, 7+ recommended)
$PSVersionTable.PSVersion

# 3. Check admin rights
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "Please run as Administrator" -ForegroundColor Red
    exit 3
}

# 4. Enable Windows Location Services (for GPS auto-detection)
# Settings > Privacy & Security > Location > On
# Scripts can enable automatically when running as admin

# 5. Internet connection required for downloads
Test-NetConnection -ComputerName www.google.com -Port 443 -InformationLevel Quiet
```

### Module Dependencies
```powershell
# Auto-install missing modules in scripts
$RequiredModules = @('PSDesiredStateConfiguration')
foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -Name $Module -ListAvailable)) {
        Install-Module -Name $Module -Force -Scope CurrentUser
    }
}
```

## Configuration Management

### Single Config File Approach
- **Template**: `EmComm-Config.template.json` (committed to repo, no secrets)
- **Actual**: `EmComm-Config.json` (gitignored, contains secrets)
- **Auto-Detection**: `device: "auto"` for COM ports, `locator: "auto"` for GPS

### Config File Structure
```json
{
  "operator": {
    "callsign": "N0CALL",
    "name": "Your Name",
    "locator": "auto"
  },
  "rig": {
    "device": "auto"
  },
  "vara": {
    "fm": {
      "licenseKey": ""
    }
  },
  "winlink": {
    "password": ""
  }
}
```

## Auto-Detection Features

### COM Port Detection
```powershell
function Find-RadioComPort {
    # Search for known USB-Serial adapters:
    # - Digirig Mobile
    # - FTDI (FT232, FT2232, etc.)
    # - Prolific (PL2303)
    # - CH340/CH341
    # - SignaLink USB
    # - CP210x (Silicon Labs)
    
    Get-CimInstance -ClassName Win32_PnPEntity | 
        Where-Object { $_.Name -match 'COM\d+' } |
        # Priority matching logic
}
```

### GPS Location Detection
```powershell
function Get-GPSLocation {
    # 1. Enable Windows Location Service (as admin)
    Set-Service -Name "lfsvc" -StartupType Automatic
    Start-Service -Name "lfsvc"
    
    # 2. Use System.Device.Location.GeoCoordinateWatcher
    # 3. Convert to Maidenhead grid square
    # 4. Graceful fallback if GPS unavailable
}
```

## Code Review Checklist

### Before Committing
- [ ] All functions use approved PowerShell verbs
- [ ] Logging implemented with `Write-Log` to `C:\Logs\`
- [ ] Error handling with try/catch blocks
- [ ] Exit codes documented and consistent
- [ ] Parameters validated with `[ValidateSet]`, `[ValidateRange]`, etc.
- [ ] Admin requirements declared with `# Requires -RunAsAdministrator`
- [ ] Help documentation complete (Synopsis, Description, Examples)
- [ ] No hardcoded paths (use `$PSScriptRoot`, `Join-Path`)
- [ ] Secrets never in code (use config file)
- [ ] Module imports use `-Force` for reliability

### Variable Naming
- **PascalCase**: `$ConfigFile`, `$LogDir`, `$InstallPath`
- **Descriptive**: `$ComPort` not `$p`, `$IsAdmin` not `$a`
- **No unused variables**: PSScriptAnalyzer will flag these

### Function Naming
- **Verb-Noun**: `Get-ComPorts`, `Set-Configuration`, `Install-Application`
- **Consistent**: If using `Get-AvailableComPorts`, don't also have `Find-ComPorts`
- **Module exports**: Explicitly `Export-ModuleMember -Function *`

## Testing Requirements

### Manual Testing
```powershell
# 1. Syntax validation
Get-Command -Syntax .\Install-EmCommSuite.ps1

# 2. Script Analyzer
Invoke-ScriptAnalyzer -Path .\Install-EmCommSuite.ps1 -Severity Warning

# 3. Dry-run test
.\Install-EmCommSuite.ps1 -ConfigFile "test-config.json" -WhatIf

# 4. Module import test
Import-Module .\Modules\EmComm-ConfigHelper.psm1 -Force
Get-Command -Module EmComm-ConfigHelper
```

### Integration Testing
- Test on clean Windows 10/11 VM
- Verify auto-detection works
- Check all installers complete successfully
- Validate configuration applied correctly

## Documentation Standards

### README.md
- Overview and features
- Prerequisites (PowerShell version, admin rights, execution policy)
- Quick start guide
- Full installation instructions
- Troubleshooting section
- License and credits

### QUICK_REFERENCE.md
- Cheat sheet format
- Most common commands
- Troubleshooting one-liners
- Pro tips

### Inline Comments
- Explain WHY, not WHAT
- Document workarounds and known issues
- Link to external resources when relevant

## Security Best Practices

### .gitignore Protection
```gitignore
# Configuration with secrets
EmComm-Config.json

# Logs
*.log
C:\Logs\*

# Backups
*.bak
*.backup

# Temporary files
*.tmp
~$*
```

### Secrets Handling
- **Never** commit license keys, passwords, API keys
- Use config files that are gitignored
- Document in README which fields need secrets
- Provide clear error messages when secrets missing

### Download Verification
```powershell
# Verify file hash after download
$ExpectedHash = "ABC123..."
$ActualHash = (Get-FileHash -Path $DownloadPath -Algorithm SHA256).Hash
if ($ActualHash -ne $ExpectedHash) {
    Write-Log "Hash mismatch - possible tampering!" -Level ERROR
    exit 1
}
```

## Common Patterns

### Download and Install
```powershell
$DownloadUrl = "https://example.com/installer.exe"
$DownloadPath = "$env:TEMP\installer.exe"
$InstallArgs = "/S /D=C:\Program Files\App"

Write-Log "Downloading from $DownloadUrl"
Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath -UseBasicParsing

Write-Log "Installing to $InstallPath"
Start-Process -FilePath $DownloadPath -ArgumentList $InstallArgs -Wait -NoNewWindow

if (Test-Path "C:\Program Files\App\app.exe") {
    Write-Log "Installation successful" -Level SUCCESS
} else {
    Write-Log "Installation failed - executable not found" -Level ERROR
    exit 1
}
```

### Registry Configuration
```powershell
$RegPath = "HKCU:\Software\AppName"
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}
Set-ItemProperty -Path $RegPath -Name "Setting" -Value "Value"
```

### INI File Manipulation
```powershell
function Set-IniValue {
    param($FilePath, $Section, $Key, $Value)
    
    $Content = Get-Content $FilePath
    $InSection = $false
    $Updated = $false
    
    for ($i = 0; $i -lt $Content.Count; $i++) {
        if ($Content[$i] -match "^\[$Section\]") {
            $InSection = $true
        }
        elseif ($InSection -and $Content[$i] -match "^$Key\s*=") {
            $Content[$i] = "$Key=$Value"
            $Updated = $true
            break
        }
        elseif ($InSection -and $Content[$i] -match "^\[") {
            break
        }
    }
    
    $Content | Set-Content $FilePath
}
```

## Intune Deployment

### Win32 App Package Structure
```
AppName.intunewin
├── Install-AppName.ps1
├── detection.ps1
└── EmComm-Config.json (injected during deployment)
```

### Detection Script Pattern
```powershell
# detection.ps1
$AppPath = "C:\Program Files\AppName\app.exe"
$MinVersion = "1.0.0"

if (Test-Path $AppPath) {
    $Version = (Get-Item $AppPath).VersionInfo.FileVersion
    if ([version]$Version -ge [version]$MinVersion) {
        Write-Host "Installed: $Version"
        exit 0
    }
}
exit 1
```

## Workflow for New Features

1. **Plan**: Outline in chat what needs to be done
2. **Implement**: Write code following these standards
3. **Test**: Validate syntax, run PSScriptAnalyzer
4. **Document**: Update README.md, QUICK_REFERENCE.md inline
5. **Report**: Summarize changes in chat, NO separate summary files
6. **Review**: Check against this instructions file

## When User Requests Changes

### DO:
- ✅ Read actual source files to verify current state
- ✅ Make surgical changes to existing files
- ✅ Update documentation inline
- ✅ Report findings in chat conversation
- ✅ Ask clarifying questions if requirements unclear
- ✅ Suggest improvements based on best practices

### DON'T:
- ❌ Create SUMMARY.md or similar documentation files
- ❌ Guess method names or parameters
- ❌ Make changes without reading current file contents
- ❌ Skip logging implementation
- ❌ Hardcode secrets or paths
- ❌ Ignore error handling

## Project-Specific Quirks

### COM Port Assignment
- Windows assigns COM ports based on hardware USB Vendor/Product ID
- **Cannot** force assignment to specific port number
- **Can** reliably detect which port radio is on via WMI/CIM queries
- Use auto-detection, provide manual override option

### Location Services
- Running as admin allows automatic enabling of Windows Location Service
- `Set-Service -Name "lfsvc" -StartupType Automatic`
- `Start-Service -Name "lfsvc"`
- GPS may not work in buildings or without hardware GPS
- Graceful fallback to manual grid square entry required

### Radio-Specific Notes
- **BTech UV-Pro**: No CAT control, VOX PTT only
- **Anytone D878/D578**: Use `flrig` NOT Hamlib (better compatibility)
- **Digirig Mobile**: Most common interface, priority in auto-detection
- **VARA FM**: Commercial license ($69), check for key before enabling

## Continuous Improvement

- Monitor PowerShell Gallery for module updates
- Follow Microsoft PowerShell best practices blog
- Review PSScriptAnalyzer rules regularly
- Update scripts for Windows 11 compatibility
- Test on clean systems periodically

---

**Remember**: Scripts should be idempotent (safe to run multiple times), well-logged, and fail gracefully with clear error messages. Users are amateur radio operators who may not be PowerShell experts - make everything as simple and automated as possible!

**73 de KD7DGF** 📻
