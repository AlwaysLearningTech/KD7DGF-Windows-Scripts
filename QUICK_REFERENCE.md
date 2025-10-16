# EmComm Suite - Quick Reference Card

## 🚀 FASTEST START

```powershell
# 1. Copy configuration template
Copy-Item EmComm-Config.template.json EmComm-Config.json

# 2. Edit YOUR callsign, passwords, and license keys (REQUIRED!)
notepad EmComm-Config.json

# 3. Install everything
.\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json"

# 4. Wait 20-40 minutes, done!
```

**Note:** EmComm-Config.json is gitignored and will NEVER be committed to your repository. It's safe to add license keys and passwords directly in this file.

---

## 🔐 AUTO-DETECTION FEATURES

The system can **automatically detect**:
- ✅ **COM ports** - Finds your Digirig/radio interface
- ✅ **GPS location** - Gets coordinates from Windows Location Services (enabled automatically as admin)
- ✅ **Grid square** - Calculates Maidenhead locator from GPS

### Check Available COM Ports
```powershell
# Import helper module
Import-Module .\Modules\EmComm-ConfigHelper.psm1

# List all COM ports
Get-AvailableComPorts

# Find radio interface automatically
Find-RadioComPort
```

### Enable GPS Auto-Detection
1. Set `"locator": "auto"` in EmComm-Config.json
2. Run installer - **Location Services enabled automatically as admin!**
3. Grid square calculated and saved

### Manual Override
If auto-detection doesn't work or you prefer manual settings:
```json
{
  "rig": { "device": "COM3" },
  "operator": { "locator": "CN87ts" }
}
```

---

## 📻 RADIO SETUP CHEAT SHEET

### BTech UV-Pro
```json
"rig": { "enabled": false },
"ptt": { "method": "VOX" }
```
**Why:** No CAT control available

### Anytone D878
```json
"rig": { "enabled": true, "useFlrig": true, "device": "COM3" },
"ptt": { "method": "CAT" }
```
**Why:** Needs flrig (not Hamlib)

### Anytone D578
```json
"rig": { "enabled": true, "useFlrig": true, "device": "COM3" },
"ptt": { "method": "CAT" }
```
**Why:** Use data port, not mic jack

---

## 📦 INDIVIDUAL APP INSTALLERS

| App | Command | Time |
|-----|---------|------|
| W1HKJ Suite | `.\Install-W1HKJSuite.ps1` | 5 min |
| VARA Modems | `.\Install-VARAModem.ps1 -ConfigFile "MyStation.json"` | 2 min |
| Winlink | `.\Install-Winlink.ps1` | 1 min |
| Direwolf | `.\Install-Direwolf.ps1 -ConfigFile "MyStation.json"` | 2 min |
| YAAC | `.\Install-YAAC.ps1 -ConfigFile "MyStation.json"` | 3 min |
| JS8Call | `.\Install-JS8Call.ps1 -ConfigFile "MyStation.json"` | 2 min |
| EchoLink | `.\Install-EchoLink.ps1 -ConfigFile "MyStation.json"` | 1 min |
| CHIRP | `.\Install-CHIRP.ps1` | 1 min |

---

## 🔧 COMMON TASKS

### Configure W1HKJ After Install
```powershell
.\Set-W1HKJConfiguration.ps1 -ConfigPackage EmComm -ConfigFile "EmComm-Config.json"
```

### Install with VARA FM License
```powershell
# Add license to EmComm-Config.json:
# "vara": { "fm": { "licenseKey": "XXXX-XXXX-XXXX-XXXX" } }

.\Install-EmCommSuite.ps1 -ConfigFile "EmComm-Config.json" -IncludeVARAFM
```

### Add Secrets to Config
```powershell
# Edit config file
notepad EmComm-Config.json

# Add your credentials directly:
# - vara.fm.licenseKey: VARA FM license ($69)
# - echolink.callsign/password: EchoLink credentials
# - winlink.password: Winlink password
# - aprs.igatePasscode: APRS passcode (if iGate)
# - apis.aprs_fi: APRS.fi API key (optional)
# - apis.qrz_com: QRZ.com API key (optional)
```

### Update CHIRP (Frequent Updates!)
```powershell
.\Install-CHIRP.ps1  # Always gets latest version
```

### View Recent Logs
```powershell
Get-ChildItem C:\Logs\*_$(Get-Date -Format 'yyyyMMdd')_*.log
```

---

## 🩺 TROUBLESHOOTING

### Script won't run
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### JSON syntax error
```powershell
Get-Content EmComm-Config.json | ConvertFrom-Json
```

### Missing callsign
Edit `EmComm-Config.json`, set `"callsign": "YOUR_CALL"`

### Missing license key or password
Edit `EmComm-Config.json` and add your credentials:
```json
{
  "vara": { "fm": { "licenseKey": "XXXX-XXXX-XXXX-XXXX" } },
  "echolink": { "callsign": "N0CALL", "password": "yourpass" },
  "winlink": { "password": "yourpass" }
}
```

### Can't find audio device
In fldigi: Configure → Audio → Select "Digirig Mobile"

### COM port not working
```powershell
# Check all COM ports
Get-WMIObject Win32_SerialPort | Select-Object DeviceID, Description

# Or use helper module
Import-Module .\Modules\EmComm-ConfigHelper.psm1
Get-AvailableComPorts
Find-RadioComPort
```

### GPS not working
```powershell
# Location Services enabled automatically when running as admin
# If GPS still not available, check manually:
# Settings → Privacy & Security → Location → On

# Test GPS manually
Import-Module .\Modules\EmComm-ConfigHelper.psm1
Get-GPSLocation
```

---

## 📚 WHERE TO FIND THINGS

| Item | Location |
|------|----------|
| **Logs** | `C:\Logs\` |
| **fldigi config** | `%USERPROFILE%\fldigi.files\` |
| **Direwolf config** | `%USERPROFILE%\direwolf.conf` |
| **YAAC config** | `%USERPROFILE%\.yaac\` |
| **JS8Call config** | `%LOCALAPPDATA%\JS8Call\` |
| **VARA config** | `%ProgramFiles(x86)%\VARA\` |

---

## 🎯 WHAT EACH APP DOES

| App | Purpose | Use Case |
|-----|---------|----------|
| **fldigi** | Digital mode terminal | PSK31, RTTY, Olivia messaging |
| **flrig** | Rig control | Control Anytone radios (better than Hamlib) |
| **flmsg** | Message forms | ICS-213, Radiogram, custom forms |
| **VARA** | High-speed modem | Winlink HF/FM (REQUIRED for Winlink) |
| **Winlink** | Email over radio | Send/receive email via HF/VHF/UHF |
| **Direwolf** | Software TNC | APRS, packet radio without hardware TNC |
| **YAAC** | APRS client | Track stations, send messages, iGate |
| **JS8Call** | Weak signal chat | Keyboard messaging when conditions poor |
| **EchoLink** | VoIP linking | Connect to repeaters via internet |
| **CHIRP** | Radio programmer | Program Baofeng, Anytone, Yaesu, Icom, etc. |

---

## 🔐 REQUIREMENTS

- ✅ Windows 10 1607+ or Windows 11
- ✅ Administrator rights
- ✅ Internet connection
- ✅ 2 GB disk space
- ✅ Digirig Mobile or similar interface
- ✅ Valid amateur radio license

---

## ⚡ SPEED RUN (Minimal Install)

**Just want Winlink? (10 minutes)**
```powershell
.\Install-W1HKJSuite.ps1
.\Install-VARAModem.ps1 -ConfigFile "EmComm-Config.json"
.\Install-Winlink.ps1
.\Set-W1HKJConfiguration.ps1 -ConfigPackage Minimal -ConfigFile "EmComm-Config.json"
```

**Just want APRS? (5 minutes)**
```powershell
.\Install-Direwolf.ps1 -ConfigFile "EmComm-Config.json"
.\Install-YAAC.ps1 -ConfigFile "EmComm-Config.json"
```

**Just want to program radios? (2 minutes)**
```powershell
.\Install-CHIRP.ps1
```

---

## 📞 GET HELP

1. **Check logs:** `C:\Logs\`
2. **Read README:** Full documentation in README.md
3. **Validate config:** `Get-Content EmComm-Config.json | ConvertFrom-Json`
4. **Test network:** `Test-NetConnection -ComputerName www.w1hkj.com -Port 443`
5. **Check auto-detection:** `Import-Module .\Modules\EmComm-ConfigHelper.psm1; Get-AvailableComPorts`

---

## 🏆 PRO TIPS

💡 **Use auto-detection!** Set `device: "auto"` and `locator: "auto"` in config  
💡 **All secrets in one file** - EmComm-Config.json is gitignored, safe for license keys!  
💡 **Location Services enabled automatically** - Just set `locator: "auto"` and run as admin  
💡 **No need to control COM port assignment** - Auto-detection finds your Digirig/FTDI/etc.  
💡 **Use flrig with Anytone radios** - Don't waste time with Hamlib  
💡 **VARA FM is FAST** - Worth the $69 for VHF/UHF Winlink  
💡 **VOX works fine** - Don't stress about CAT control on simple radios  
💡 **Update CHIRP often** - New radios added frequently  
💡 **Direwolf is amazing** - No need to buy a hardware TNC  
💡 **Check COM ports first** - Use `Get-AvailableComPorts` to troubleshoot  

---

**73 de KD7DGF** 📻

