# KD7DGF Windows Scripts

A collection of PowerShell scripts for deploying and managing applications through Microsoft Intune.

## Overview

This repository contains PowerShell scripts designed to facilitate application deployment via Microsoft Intune. The scripts follow best practices for Intune Win32 app deployment and include templates that can be customized for various applications.

## Repository Structure

```
Intune/
├── Templates/           # Reusable script templates
│   ├── Install-Application.ps1      # Installation template
│   ├── Uninstall-Application.ps1    # Uninstallation template
│   └── Detection-Application.ps1    # Detection template
└── Examples/            # Example implementations
    ├── Install-7Zip.ps1
    ├── Detection-7Zip.ps1
    ├── Uninstall-7Zip.ps1
    ├── Install-GoogleChrome.ps1
    └── Detection-GoogleChrome.ps1
```

## Templates

### Install-Application.ps1
A comprehensive template for installing applications via Intune. Features include:
- Support for MSI and EXE installers
- Detailed logging to `%ProgramData%\Intune\Logs`
- Administrator privilege checking
- Pre and post-installation tasks
- Error handling and exit codes

**Usage:**
```powershell
.\Install-Application.ps1 -AppName "MyApp" -InstallerPath "C:\Temp\setup.msi"
```

### Uninstall-Application.ps1
Template for uninstalling applications. Features include:
- Support for MSI Product Code uninstallation
- Automatic application discovery via registry
- UninstallString execution
- Post-uninstallation cleanup
- Comprehensive logging

**Usage:**
```powershell
.\Uninstall-Application.ps1 -AppName "MyApp" -ProductCode "{GUID}"
```

### Detection-Application.ps1
Template for detecting installed applications. Intune uses detection scripts to determine if an application is already installed. Features include:
- Multiple detection methods (file path, registry, installed apps)
- Version comparison support
- Proper exit codes for Intune

**Usage:**
```powershell
.\Detection-Application.ps1 -AppName "MyApp" -Version "1.0.0"
```

## Example Scripts

### 7-Zip Deployment
Complete set of scripts for deploying 7-Zip:
- `Install-7Zip.ps1` - Installs 7-Zip from MSI
- `Detection-7Zip.ps1` - Detects 7-Zip installation
- `Uninstall-7Zip.ps1` - Removes 7-Zip

**Requirements:**
- Download 7-Zip MSI from [7-zip.org](https://www.7-zip.org/download.html)
- Place MSI in same directory as install script

### Google Chrome Deployment
Scripts for deploying Google Chrome Enterprise:
- `Install-GoogleChrome.ps1` - Installs Chrome from MSI
- `Detection-GoogleChrome.ps1` - Detects Chrome installation

**Requirements:**
- Download Chrome Enterprise MSI from [Google Chrome Enterprise](https://cloud.google.com/chrome-enterprise/browser/download/)
- Place MSI in same directory as install script

## Using with Intune

### Packaging Win32 Apps

1. **Prepare your files:**
   - Installation script (e.g., `Install-7Zip.ps1`)
   - Installer file (MSI or EXE)
   - Any additional files required

2. **Download the Microsoft Win32 Content Prep Tool:**
   ```powershell
   # Download from: https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool
   ```

3. **Create the .intunewin package:**
   ```powershell
   .\IntuneWinAppUtil.exe -c "C:\Source" -s "Install-App.ps1" -o "C:\Output"
   ```

4. **Upload to Intune:**
   - Go to Microsoft Endpoint Manager admin center
   - Apps > All apps > Add
   - Select "Windows app (Win32)"
   - Upload the .intunewin file

5. **Configure the app:**
   - **Install command:** `powershell.exe -ExecutionPolicy Bypass -File Install-App.ps1`
   - **Uninstall command:** `powershell.exe -ExecutionPolicy Bypass -File Uninstall-App.ps1`
   - **Detection rules:** Use custom script and upload your detection script

### Best Practices

1. **Logging:**
   - All scripts log to `%ProgramData%\Intune\Logs`
   - Review logs for troubleshooting

2. **Testing:**
   - Always test scripts locally before deploying via Intune
   - Test on a clean system to verify detection logic
   - Verify both install and uninstall work correctly

3. **Exit Codes:**
   - 0 = Success
   - 1 = General failure
   - 3010 = Success with restart required
   - Other codes = Specific installer errors

4. **Detection Scripts:**
   - Must exit with code 0
   - Output to stdout = detected
   - No output = not detected
   - Error (exit code 1) = detection failed

5. **Execution Policy:**
   - Scripts should be run with `-ExecutionPolicy Bypass`
   - Intune runs scripts in SYSTEM context

## Customizing Templates

To create a new deployment script:

1. Copy the appropriate template from `Intune/Templates/`
2. Modify the installation/uninstallation logic for your application
3. Update detection logic to match your application's installation
4. Test thoroughly before deploying

## Requirements

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Administrator privileges for installation/uninstallation
- Microsoft Intune subscription (for Intune deployment)

## Contributing

Feel free to submit pull requests with:
- New example scripts for common applications
- Improvements to existing templates
- Bug fixes or enhancements

## License

This project is provided as-is for use with Microsoft Intune deployments.

## Author

KD7DGF

## Version History

- **1.0** (2025-10-11) - Initial release
  - Installation, Uninstallation, and Detection templates
  - Example scripts for 7-Zip and Google Chrome