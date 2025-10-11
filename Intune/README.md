# Intune Deployment Scripts

This directory contains PowerShell scripts for deploying Win32 applications through Microsoft Intune.

## Directory Structure

### Templates/
Production-ready script templates that can be customized for any application:

- **Install-Application.ps1** - Universal installation template
- **Uninstall-Application.ps1** - Universal uninstallation template
- **Detection-Application.ps1** - Universal detection template
- **Check-SystemRequirements.ps1** - System requirements validation

### Examples/
Complete working examples for common applications:

- **7-Zip** - Complete deployment package (install, detect, uninstall)
- **Google Chrome** - Browser deployment example (install, detect)

## Quick Start

### 1. Choose Your Approach

**Option A: Use Templates (Recommended for custom apps)**
```powershell
# Copy template
Copy-Item Templates\Install-Application.ps1 MyApp\Install-MyApp.ps1

# Customize for your application
# Edit the installation logic section
```

**Option B: Use Examples (For supported apps)**
```powershell
# Use as-is or customize
# Download required installer
# Deploy via Intune
```

### 2. Create Intune Package

```powershell
# Package structure
MyApp\
  ├── Install-MyApp.ps1
  ├── Detection-MyApp.ps1
  ├── Uninstall-MyApp.ps1
  └── setup.msi (or .exe)

# Create .intunewin package
.\IntuneWinAppUtil.exe -c "C:\MyApp" -s "Install-MyApp.ps1" -o "C:\Output"
```

### 3. Configure in Intune

1. **Upload .intunewin** to Intune portal
2. **Install command:**
   ```
   powershell.exe -ExecutionPolicy Bypass -File Install-MyApp.ps1
   ```
3. **Uninstall command:**
   ```
   powershell.exe -ExecutionPolicy Bypass -File Uninstall-MyApp.ps1
   ```
4. **Detection rule:** Custom script - upload Detection-MyApp.ps1

## Script Parameters

### Install-Application.ps1

| Parameter | Required | Description |
|-----------|----------|-------------|
| AppName | Yes | Application name for logging |
| InstallerPath | No | Path to installer file |
| InstallPath | No | Custom installation directory |
| Arguments | No | Additional installer arguments |

### Uninstall-Application.ps1

| Parameter | Required | Description |
|-----------|----------|-------------|
| AppName | Yes | Application name for logging |
| ProductCode | No | MSI product code GUID |
| UninstallString | No | Custom uninstall command |

### Detection-Application.ps1

| Parameter | Required | Description |
|-----------|----------|-------------|
| AppName | Yes | Application name to search for |
| Version | No | Minimum version required |
| InstallPath | No | File path to check |
| RegistryPath | No | Registry key to check |
| RegistryValue | No | Registry value to check |

### Check-SystemRequirements.ps1

| Parameter | Required | Description |
|-----------|----------|-------------|
| MinimumRAMGB | No | Minimum RAM in GB |
| MinimumDiskSpaceGB | No | Minimum free disk space in GB |
| MinimumOSVersion | No | Minimum Windows version |
| RequiredFeatures | No | Array of required Windows features |
| OutputDetails | No | Switch to show detailed output |

## Detection Script Guidelines

Detection scripts are critical for Intune to determine installation state:

### Return Codes
- **Exit 0 with output** = Application detected (installed)
- **Exit 0 without output** = Application not detected (not installed)
- **Exit 1** = Error during detection

### Example Detection Methods

**Method 1: File Path**
```powershell
if (Test-Path "C:\Program Files\MyApp\app.exe") {
    Write-Host "MyApp detected"
    exit 0
}
exit 0
```

**Method 2: Registry**
```powershell
$regPath = "HKLM:\SOFTWARE\MyApp"
if (Test-Path $regPath) {
    Write-Host "MyApp detected"
    exit 0
}
exit 0
```

**Method 3: Version Check**
```powershell
$app = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object { $_.DisplayName -like "*MyApp*" }

if ($app -and $app.DisplayVersion -ge "1.0") {
    Write-Host "MyApp version $($app.DisplayVersion) detected"
    exit 0
}
exit 0
```

## Logging

All scripts log to: `%ProgramData%\Intune\Logs\`

Log files are named: `Install-AppName.log`, `Uninstall-AppName.log`

### Log Levels
- **Info** - Normal operation (Green)
- **Warning** - Non-critical issues (Yellow)
- **Error** - Failures (Red)

### Accessing Logs
```powershell
# View latest log
Get-Content "$env:ProgramData\Intune\Logs\Install-MyApp.log" -Tail 50

# View all logs
Get-ChildItem "$env:ProgramData\Intune\Logs"
```

## Common Installer Types

### MSI Installers
```powershell
# Silent install
msiexec.exe /i "installer.msi" /qn /norestart

# With logging
msiexec.exe /i "installer.msi" /qn /norestart /l*v "install.log"

# Uninstall
msiexec.exe /x "{PRODUCT-CODE-GUID}" /qn /norestart
```

### EXE Installers
Common silent switches:
- `/S` or `/silent` - Most installers
- `/quiet` - Microsoft installers
- `/verysilent` - Inno Setup installers
- `-silent` - NSIS installers

```powershell
# Silent install
Start-Process "installer.exe" -ArgumentList "/S" -Wait

# Check exit code
$process = Start-Process "installer.exe" -ArgumentList "/S" -Wait -PassThru
if ($process.ExitCode -eq 0) {
    Write-Host "Success"
}
```

## Testing Scripts

### Local Testing
```powershell
# Test as SYSTEM (Intune context)
psexec -i -s powershell.exe

# Run installation
.\Install-MyApp.ps1 -AppName "MyApp" -InstallerPath "setup.msi"

# Test detection
.\Detection-MyApp.ps1 -AppName "MyApp"

# Test uninstallation
.\Uninstall-MyApp.ps1 -AppName "MyApp"
```

### Validation Checklist
- [ ] Script runs without errors
- [ ] Installation completes successfully
- [ ] Detection script returns correct state
- [ ] Uninstallation removes the application
- [ ] Logs are created in expected location
- [ ] Exit codes are correct
- [ ] Works in SYSTEM context

## Exit Codes Reference

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General failure |
| 1602 | User cancelled installation |
| 1603 | Fatal error during installation |
| 1618 | Another installation in progress |
| 1641 | Success, restart initiated |
| 3010 | Success, restart required |

## Troubleshooting

### Common Issues

**Issue: Script execution is blocked**
```powershell
# Solution: Use -ExecutionPolicy Bypass
powershell.exe -ExecutionPolicy Bypass -File script.ps1
```

**Issue: Application not detected after installation**
- Check detection script logic
- Verify file paths are correct
- Ensure detection runs in SYSTEM context
- Review detection script output manually

**Issue: Installation fails silently**
- Check installer logs
- Verify installer is correct architecture (x64/x86)
- Test installer manually with same parameters
- Check system requirements

**Issue: Logs not created**
- Verify `%ProgramData%\Intune\Logs` directory exists
- Check script has write permissions
- Run script as administrator

## Best Practices

1. **Always test locally** before deploying to Intune
2. **Use SYSTEM context** for testing (matches Intune)
3. **Handle errors gracefully** with try-catch blocks
4. **Log everything** for troubleshooting
5. **Check prerequisites** before installation
6. **Use proper exit codes** for Intune to understand results
7. **Keep scripts simple** - avoid unnecessary complexity
8. **Document customizations** in script comments
9. **Version your scripts** for tracking changes
10. **Test uninstall** as thoroughly as install

## Additional Resources

- [Microsoft Intune Win32 App Management](https://docs.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management)
- [Win32 Content Prep Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)

## Support

For issues or questions:
- Review logs in `%ProgramData%\Intune\Logs`
- Check Intune device diagnostics
- Consult Microsoft Endpoint Manager admin center
