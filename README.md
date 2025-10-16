# KD7DGF Windows Scripts

**Complete EmComm Software Deployment Suite** - PowerShell automation for emergency communications and amateur radio software.

## 🚀 Quick Start

**Prerequisites:**
```powershell
# 1. Set PowerShell execution policy (one-time, run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2. Verify PowerShell version (5.1+ required, 7+ recommended)
$PSVersionTable.PSVersion

# 3. Enable Windows Location Services for GPS auto-detection (optional)
# Settings > Privacy & Security > Location > On
# (Scripts can enable automatically when running as Administrator)
```

**Installation:**
```powershell
# 1. Copy and customize configuration
Copy-Item EmComm-Config.template.json EmComm-Config.json
notepad EmComm-Config.json  # Set your callsign, license keys, and passwords

# 2. Install everything with one command (run as Administrator)
.\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json"

# Done! All EmComm software installed and configured.
```

---

## 📦 What Gets Installed

### Digital Modes & EmComm
- ✅ **W1HKJ Suite** (15 apps) - fldigi, flrig, flmsg, flamp, etc.
- ✅ **VARA HF/FM** - High-speed modems for Winlink
- ✅ **Winlink Express** - Email over radio
- ✅ **JS8Call** - Weak signal keyboard chat
- ✅ **EchoLink** - VoIP radio linking

### APRS & Packet
- ✅ **Direwolf** - Software TNC
- ✅ **YAAC** - APRS client

### Radio Programming
- ✅ **CHIRP Next** - Multi-brand radio programmer
- ✅ **DMRconfig** - Command-line DMR tool
- ✅ **Anytone D878 CPS** - Official D878UV programming
- ✅ **Anytone D578 CPS** - Official D578UV programming

---

## 📋 Table of Contents

- [Prerequisites](#-quick-start)
- [Installation Scripts](#installation-scripts)
- [Configuration Templates](#configuration-templates)
- [Radio-Specific Settings](#radio-specific-settings)
- [Deployment Workflows](#deployment-workflows)
- [Intune Deployment](#intune-deployment)
- [Troubleshooting](#troubleshooting)

---

## 🛠️ Installation Scripts

### Master Installer

#### Install-EmCommSuite.ps1
**One command to install everything.**

```powershell
# Full installation with all defaults
.\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json"

# Include VARA FM (license key in config file: vara.fm.licenseKey)
.\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json" -IncludeVARAFM

# Include Anytone programming software
.\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json" `
    -IncludeAnytoneD878CPS `
    -IncludeAnytoneD578CPS

# Minimal installation (W1HKJ + Winlink only)
.\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json" `
    -IncludeVARA:$false `
    -IncludeDirewolf:$false `
    -IncludeYAAC:$false `
    -IncludeEchoLink:$false `
    -IncludeJS8Call:$false `
    -IncludeCHIRP:$false
```

**Installation time:** 20-40 minutes  
**Log:** `C:\Logs\EmCommSuite_Install_*.log`

---

### Individual Application Installers

#### Install-W1HKJSuite.ps1
Installs all 15 W1HKJ applications (fldigi, flrig, flmsg, flamp, fllog, flnet, flwkey, flwrap, flcluster, flaa, nanoIO, kcat, comptext, comptty, linsim).

```powershell
.\Install-W1HKJSuite.ps1
```

#### Install-VARAModem.ps1
Installs VARA HF (free) and optionally VARA FM ($69 license required).

```powershell
# VARA HF only (free)
.\Install-VARAModem.ps1 -ConfigFile "EmComm-Config.json"

# Include VARA FM (license key from config: vara.fm.licenseKey)
.\Install-VARAModem.ps1 -ConfigFile "EmComm-Config.json" -IncludeFM
```

#### Install-Winlink.ps1
Installs Winlink Express for email over radio.

```powershell
.\Install-Winlink.ps1
```

#### Install-Direwolf.ps1
Installs Direwolf software TNC with pre-configured settings.

```powershell
.\Install-Direwolf.ps1 -ConfigFile "EmComm-Config.json"
```

#### Install-YAAC.ps1
Installs YAAC (Yet Another APRS Client) with Java runtime.

```powershell
.\Install-YAAC.ps1 -ConfigFile "EmComm-Config.json"
```

#### Install-EchoLink.ps1
Installs EchoLink VoIP for internet-linked amateur radio.

```powershell
.\Install-EchoLink.ps1 -ConfigFile "EmComm-Config.json"
```

#### Install-JS8Call.ps1
Installs JS8Call for weak signal keyboard-to-keyboard communications.

```powershell
.\Install-JS8Call.ps1 -ConfigFile "EmComm-Config.json"
```

#### Install-CHIRP.ps1
Installs latest CHIRP Next for radio programming. **CHIRP updates frequently** - rerun to get latest version.

```powershell
.\Install-CHIRP.ps1
```

#### Install-DMRconfig.ps1
Installs DMRconfig command-line tool for DMR codeplug management.

```powershell
.\Install-DMRconfig.ps1
```

#### Install-AnytoneD878CPS.ps1
Installs official Anytone AT-D878UVII Plus V2 CPS from Bridgecom.

```powershell
.\Install-AnytoneD878CPS.ps1
```

#### Install-AnytoneD578CPS.ps1
Installs official Anytone AT-D578UVIII Plus V2 CPS from Bridgecom.

```powershell
.\Install-AnytoneD578CPS.ps1
```

#### Set-W1HKJConfiguration.ps1
Deploys W1HKJ configuration from JSON template.

```powershell
.\Set-W1HKJConfiguration.ps1 -ConfigPackage EmComm -ConfigFile "EmComm-Config.json"
```

**Packages:** EmComm | ARES | PublicService | Minimal | All

---

### Utility Installers

#### Install-PowerShell7.ps1
Installs/upgrades PowerShell 7 via winget.

```powershell
.\Install-PowerShell7.ps1
```

#### Install-GoogleDrive.ps1
Installs Google Drive for Desktop with G: drive mapping.

```powershell
.\Install-GoogleDrive.ps1
```

---

## ⚙️ Configuration Templates

### EmComm-Config.template.json
**Master configuration template** for all EmComm software. Copy and customize:

```powershell
Copy-Item EmComm-Config.template.json EmComm-Config.json
notepad EmComm-Config.json
```

**Key sections:**
```json
{
  "operator": {
    "callsign": "KD7DGF",           // REQUIRED
    "name": "David",
    "qth": "Seattle, WA",
    "locator": "CN87",              // Maidenhead grid
    "latitude": "47.6062",
    "longitude": "-122.3321"
  },
  "audio": {
    "captureDevice": "Digirig Mobile",
    "playbackDevice": "Digirig Mobile"
  },
  "rig": {
    "enabled": true,
    "useFlrig": true,               // For Anytone radios
    "model": "AT-D878UV",
    "device": "COM3",
    "baudRate": 9600
  },
  "ptt": {
    "method": "CAT"                 // VOX, CAT, RTS, DTR
  },
  "vara": {
    "installHF": true,
    "installFM": false,
    "fmLicenseKey": ""
  },
  "aprs": {
    "enableDigipeater": false,
    "enableIGate": false,
    "igatePasscode": ""             // Get from apps.magicbug.co.uk
  }
}
```

### W1HKJ-Config.template.json
**Legacy W1HKJ-only configuration** (use EmComm-Config instead for new deployments).

---

## 📻 Radio-Specific Settings

### BTech UV-Pro (via Digirig Mobile)

**Limitations:** No CAT control, VOX PTT only

```json
{
  "audio": {
    "captureDevice": "Digirig Mobile",
    "playbackDevice": "Digirig Mobile"
  },
  "rig": {
    "enabled": false
  },
  "ptt": {
    "method": "VOX"
  }
}
```

**Why no CAT?** BTech UV-Pro doesn't support computer control.

---

### Anytone AT-D878UVII Plus (via Digirig Mobile)

**Best for:** VHF/UHF digital modes, VARA FM, Winlink

```json
{
  "audio": {
    "captureDevice": "Digirig Mobile",
    "playbackDevice": "Digirig Mobile"
  },
  "rig": {
    "enabled": true,
    "useFlrig": true,
    "device": "COM3",
    "baudRate": 9600
  },
  "ptt": {
    "method": "CAT"
  }
}
```

**Why flrig?** Anytone radios not officially supported by Hamlib. **flrig** (included in W1HKJ suite) has native Anytone AT-D878 support.

**Setup:**
1. Connect Digirig to radio speaker/mic
2. Connect USB cable for CAT control (COM port)
3. In flrig: Select "AT-D878UV" rig
4. Set baud rate to 9600

---

### Anytone AT-D578UVIII Plus (via data port)

**Best for:** HF/VHF/UHF all modes, base/mobile operation

```json
{
  "audio": {
    "captureDevice": "Digirig Mobile",
    "playbackDevice": "Digirig Mobile"
  },
  "rig": {
    "enabled": true,
    "useFlrig": true,
    "device": "COM3",
    "baudRate": 9600
  },
  "ptt": {
    "method": "CAT"
  }
}
```

**Why flrig?** Use **flrig** with AT-578 driver for full compatibility.

**Setup:**
1. Connect via 6-pin mini-DIN data port (NOT microphone jack)
2. Data port provides audio + CAT control
3. In flrig: Select "AT-578UV" rig
4. Set baud rate to 9600

---

## 🔄 Deployment Workflows

### Manual Installation

```powershell
# 1. Ensure PowerShell 7 is installed
pwsh --version

# 2. Create configuration
Copy-Item EmComm-Config.template.json EmComm-Config.json
notepad EmComm-Config.json  # Set callsign and radio settings

# 3. Validate JSON syntax
Get-Content EmComm-Config.json | ConvertFrom-Json

# 4. Run master installer (as Administrator)
.\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json"
```

### Staged Installation

```powershell
# Stage 1: Core digital modes
.\Install-W1HKJSuite.ps1
.\Set-W1HKJConfiguration.ps1 -ConfigPackage EmComm -ConfigFile "EmComm-Config.json"

# Stage 2: Winlink capability
.\Install-VARAModem.ps1 -ConfigFile "EmComm-Config.json"
.\Install-Winlink.ps1

# Stage 3: APRS/packet
.\Install-Direwolf.ps1 -ConfigFile "EmComm-Config.json"
.\Install-YAAC.ps1 -ConfigFile "EmComm-Config.json"

# Stage 4: Additional tools
.\Install-JS8Call.ps1 -ConfigFile "EmComm-Config.json"
.\Install-EchoLink.ps1 -ConfigFile "EmComm-Config.json"
.\Install-CHIRP.ps1
```

---

## 🏢 Intune Deployment

### Recommended App Structure

Deploy as separate Win32 apps for flexibility:

1. **PowerShell 7** (optional, System context)
2. **EmComm Core** (W1HKJ + VARA + Winlink, System context)
3. **EmComm APRS** (Direwolf + YAAC, System context)
4. **EmComm Tools** (JS8Call + EchoLink, System context)
5. **Radio Programming** (CHIRP + Anytone CPS, System context)
6. **W1HKJ Configuration** (User context, requires customized JSON)

### Package Creation

```powershell
# Create .intunewin package
IntuneWinAppUtil.exe -c "C:\Scripts\EmComm" -s "Install-EmCommSuite.ps1" -o "C:\IntunePackages"

# Include configuration file in package
Copy-Item EmComm-Config.json C:\Scripts\EmComm\EmComm-Config.json
```

### App 1: EmComm Core

**Install command:**
```
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-EmCommSuite.ps1" -ConfigFile "EmComm-Config.json" -W1HKJConfigPackage EmComm -IncludeDirewolf:$false -IncludeYAAC:$false -IncludeEchoLink:$false -IncludeJS8Call:$false -IncludeCHIRP:$false
```

**Detection:** File exists `C:\Program Files (x86)\fldigi\fldigi.exe`

### App 2: EmComm APRS

**Install command:**
```
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "Install-Direwolf.ps1" -ConfigFile "EmComm-Config.json"
```

**Detection:** File exists `C:\Program Files\Direwolf\direwolf.exe`

---

## 🩺 Troubleshooting

### Installation Issues

**Execution policy error:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Download failures:**
```powershell
# Test network connectivity
Test-NetConnection -ComputerName www.w1hkj.com -Port 443
Test-NetConnection -ComputerName rosmodem.wordpress.com -Port 443
Test-NetConnection -ComputerName downloads.winlink.org -Port 443
```

**JSON syntax errors:**
```powershell
# Validate JSON
Get-Content EmComm-Config.json | ConvertFrom-Json

# Common errors:
# - Missing comma between properties
# - Trailing comma in last property
# - Unescaped quotes in strings
```

### Configuration Issues

**Callsign not set:**
```powershell
# Verify callsign in JSON
$Config = Get-Content EmComm-Config.json | ConvertFrom-Json
$Config.operator.callsign  # Should show your callsign
```

**Audio devices not found:**
```powershell
# List available audio devices (in fldigi or VARA)
# Or use this PowerShell snippet:
Get-PnpDevice -Class AudioEndpoint | Where-Object {$_.Status -eq "OK"}
```

**COM port issues:**
```powershell
# List available COM ports
Get-WMIObject Win32_SerialPort | Select-Object Name, DeviceID, Description
```

### View Logs

```powershell
# Latest EmComm suite installation
Get-ChildItem C:\Logs\EmCommSuite_Install_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 100

# Latest W1HKJ installation
Get-ChildItem C:\Logs\W1HKJ_Installer_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50

# Latest configuration deployment
Get-ChildItem C:\Logs\W1HKJ_Config_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50

# All logs from today
Get-ChildItem C:\Logs\*_$(Get-Date -Format 'yyyyMMdd')_*.log | Sort-Object LastWriteTime
```

---

## 📚 Application Details

### W1HKJ Suite Components

- **fldigi** - Digital mode terminal (PSK31, RTTY, Olivia, MFSK, etc.)
- **flrig** - Rig control (better Anytone support than Hamlib)
- **flmsg** - Message forms (ICS-213, Radiogram, custom)
- **flamp** - Automatic Multicast Protocol (file transfer)
- **fllog** - Logging and QSL management
- **flnet** - Net control logger
- **flwkey** - Winkeyer interface
- **flwrap** - File wrapper for transmission
- **flcluster** - DX cluster monitor
- **flaa** - Antenna analyzer interface
- **nanoIO** - Nano IO board control
- **kcat** - Remote rig control
- **comptext** - Text composer
- **comptty** - RTTY composer
- **linsim** - Transmission line simulator

### VARA Modems

- **VARA HF** - Free, 2.4 kHz bandwidth, up to 19 wpm text, 180 bps data
- **VARA FM** - $69 license, 25 kHz bandwidth, up to 3,000 bps data

### Winlink Modes

- **VARA HF** - Best for HF Winlink (fastest, most reliable)
- **VARA FM** - Best for VHF/UHF Winlink (very fast)
- **ARDOP** - Free HF alternative (slower than VARA HF)
- **Packet** - Legacy VHF/UHF (requires TNC)

---

## 🔐 Requirements

- **OS:** Windows 10 1607+ or Windows 11
- **PowerShell:** 7.0+ (auto-installs if missing)
- **Privileges:** Administrator for installation
- **Internet:** Required for downloading installers
- **Disk Space:** ~2 GB for full suite
- **RAM:** 8 GB recommended

### Hardware Requirements

- **Sound card interface:** Digirig Mobile, SignaLink USB, or equivalent
- **Radio:** Any amateur radio with audio input/output
- **CAT control (optional):** USB or serial cable for rig control
- **For APRS/packet:** TNC hardware (optional, Direwolf is software TNC)

---

## 📖 Best Practices

### PowerShell Naming
Scripts use approved verbs (Install, Set) with Verb-Noun pattern.

### Configuration Management
- Use JSON files for all settings
- Validate JSON syntax before deployment
- Store organizational templates in version control
- Never commit license keys to repositories

### Intune Deployment
- Use Win32 app format (.intunewin)
- Separate installation and configuration apps
- System context for installation, User context for configuration only if needed
- Define dependencies: PowerShell 7 → Apps → Configuration

### Security
- Validate all downloads with checksums (where available)
- Use official download sources only
- Review scripts before execution
- Monitor logs for anomalies

---

## 📝 License

Scripts provided as-is for amateur radio and emergency communications use. Individual applications have their own licenses.

---

## 👤 Author

**KD7DGF** - David Snyder  
Emergency Communications | Software Automation | Amateur Radio

---

## 🤝 Contributing

- Test thoroughly on fresh Windows installations
- Use approved PowerShell verbs
- Update documentation
- Include Intune deployment instructions
- Add logging to all new scripts

---

## 🚧 Future Enhancements

- [ ] Windows Store deployment scripts
- [ ] Configuration validation tool
- [ ] Automated update checker for CHIRP
- [ ] Parallel installation for non-conflicting apps
- [ ] Automated testing framework
- [ ] Pre-configured codeplug templates
- [ ] Integration with amateur radio databases (RepeaterBook, etc.)

---

## 📋 Version History

### v3.0 (2025-10-15)
- **New:** Complete EmComm suite installer (Install-EmCommSuite.ps1)
- **New:** VARA HF/FM installation with audio pre-configuration
- **New:** Direwolf software TNC with config generation
- **New:** YAAC APRS client with Java auto-install
- **New:** EchoLink VoIP with registry pre-configuration
- **New:** JS8Call weak signal modes
- **New:** CHIRP Next with auto-update detection
- **New:** DMRconfig command-line tool
- **New:** Anytone D878/D578 CPS installers
- **New:** EmComm-Config.template.json master configuration
- **Enhanced:** Comprehensive radio-specific configurations
- **Enhanced:** Integrated audio device settings across all apps
- **Enhanced:** USB driver installation for Anytone radios

### v2.0 (2025-10-14)
- Breaking change: ConfigPackage now REQUIRED parameter
- Breaking change: Callsign REQUIRED in JSON
- Renamed scripts for PowerShell naming standards
- Added radio-specific configurations (BTech, Anytone D878, D578)
- Documented KISS TNC incompatibility with fldigi
- Added flrig integration for Anytone radios
- Standardized error handling and logging
- Consolidated documentation

### v1.0 (2025-10-13)
- Initial release with W1HKJ suite installer
- Dynamic version detection
- PowerShell 7 auto-upgrade
- Intune deployment support
- EmComm, ARES, PublicService, and Minimal packages

---

**73 de KD7DGF** 📻🚨

