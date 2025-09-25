# Teams Squared Device Enrollment Package

Welcome to the Teams Squared Device Enrollment system! This package contains everything needed to enroll your Windows device into our secure corporate environment.

## What This Does

This enrollment process will automatically:

- **Configure your device** with the correct name and security settings
- **Install security software** (Bitdefender and Miradore MDM)
- **Apply security policies** to protect your device and data
- **Complete in 6 stages** with automatic progress tracking

## Quick Start

1. **Extract all files** from this package to a single folder on your desktop
2. **Right-click** on `enroll.ps1`
3. **Select "Run with PowerShell"** (as Administrator)
4. **Follow the prompts** - you'll need your Teams Squared email address

## What You'll Need

- **Administrator access** to your Windows computer
- **Your Teams Squared email address** (e.g., john@teamsquared.io)
- **Internet connection** for the enrollment process
- **About 10-15 minutes** to complete the process

## What Happens During Enrollment

The process runs in 6 stages:

1. **Prechecks** - Validates your email and gets device configuration
2. **Rename Computer** - Sets your device name (may require a reboot)
3. **Miradore MDM** - Installs mobile device management software
4. **Bitdefender** - Installs security software
5. **Security Policies** - Applies Windows security settings
6. **Finalize** - Completes enrollment and shows summary

## Important Notes

- **Keep all files together** - The script needs all files in the same folder
- **Don't delete anything** - All files are required for the enrollment process
- **Reboot may be required** - Your computer may restart during the process
- **Stay logged in** - The process will resume automatically after any reboot

## Troubleshooting

### If the script won't run:

- Make sure you're running as Administrator
- Check that all files are in the same folder
- Ensure you have internet connectivity

### If enrollment fails:

- Note the error message and stage number
- Contact: **cybersecurity@teamsquared.io**
- Include your device name and the error details

### Common Issues:

- **"Execution Policy" error**: Run PowerShell as Administrator and type: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **"File not found" error**: Make sure all files are extracted to the same folder
- **"Access denied" error**: Run PowerShell as Administrator

## What Gets Installed

- **Miradore MDM**: Mobile device management for corporate security
- **Bitdefender GravityZone**: Enterprise antivirus and security
- **Windows Security Policies**: USB controls, firewall, and other security settings

## After Enrollment

Once complete, your device will be:

- ✅ Properly named and configured
- ✅ Protected with enterprise security software
- ✅ Managed by our IT team
- ✅ Compliant with company security policies

## Support

If you need help:

- **Email**: cybersecurity@teamsquared.io
- **Include**: Your device name, error message, and stage number
- **Response time**: Usually within 24 hours

---

**Version**: 1.0.1  
**Last Updated**: 2025-09-25  
**Package**: Teams Squared Device Enrollment
