# TS2 Enrollment Wizard PowerShell

PowerShell-based CLI tool for Teams Squared's device enrollment system.

## Features

- **Automated Enrollment**: Complete device enrollment in 6 stages
- **State Persistence**: Survives reboots with automatic resume
- **Dual Logging**: Local logs and backend API reporting
- **Security Policies**: Windows registry and network policy enforcement
- **MDM Integration**: Miradore and Bitdefender agent installation
- **Error Recovery**: Graceful error handling with detailed reporting

## Quick Start

```powershell
# Run as Administrator
.\enroll.ps1

# Or via installer
TS2-Enrollment-Setup.exe
```

## Installation

The wizard is distributed as a Windows installer (`TS2-Enrollment-Setup.exe`) that:
- Installs to `C:\ProgramData\TS2\Wizard\`
- Creates Start Menu shortcuts
- Sets up required directory structure
- Includes all necessary assets and scripts

## Enrollment Stages

1. **Prechecks** - Environment validation and API lookup
2. **Rename** - Computer rename and reboot scheduling
3. **Miradore** - MDM client installation
4. **Bitdefender** - Security agent installation
5. **Policies** - Windows security policy application
6. **Finalize** - Completion reporting and cleanup

## Configuration

Requires `config.json` with device-specific JWT token:

```json
{
  "apiBase": "http://localhost:5000",
  "enrollmentDeviceId": "ckz123...",
  "jwt": "<24h single-use token>",
  "expiresAt": "2025-09-04T12:00:00.000Z"
}
```

## File Structure

```
C:\ProgramData\TS2\Wizard\
  enroll.ps1             # Main orchestrator
  scripts\               # Stage implementations
  config\config.json     # Device configuration
  state\state.json       # Progress tracking
  assets\                # Installer files
    mdm.msi             # Miradore installer
    epskit_x64.exe      # Bitdefender installer
    installer.xml       # Bitdefender configuration
```

## Security Policies

Applied based on policy IDs from backend:
- **50/51**: USB storage controls
- **52**: MTP/WPD blocking
- **60/61**: Session security
- **70**: Windows Firewall
- **80**: Windows Update settings

## Requirements

- Windows 10/11
- PowerShell 5.1+ or PowerShell 7
- Administrator privileges
- Internet connectivity
- Local user account (not Microsoft/Azure AD)

## Build Process

```powershell
# Compile installer (requires Inno Setup)
iscc installer.iss

# Output: dist/TS2-Enrollment-Setup.exe
```

## Assets

The `src/assets/` directory contains:
- `mdm.msi` - Miradore MDM installer
- `epskit_x64.exe` - Bitdefender security agent
- `installer.xml` - Bitdefender configuration
- `icon.ico` / `icon.png` - Application icons

**Note**: These files are excluded from git via `.gitignore` due to size and licensing restrictions. They must be obtained separately and placed in the assets directory before building the installer.

## Stack

PowerShell + Inno Setup + Windows Registry + Scheduled Tasks.
