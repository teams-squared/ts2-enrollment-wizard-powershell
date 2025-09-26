Teams Squared Device Enrollment
==============================

This package will automatically configure your Windows device for our corporate environment.

QUICK START:
1. Extract all files to a folder on your desktop
2. Double-click "run-enrollment.bat" (as Administrator)
3. Follow the prompts - you'll need your Teams Squared email address
4. Watch the video guide: https://teamsquared.io/enrollment-video

WHAT YOU NEED:
- Administrator access to your computer
- Your Teams Squared email address (e.g., john@teamsquared.io)
- Internet connection
- About 20-30 minutes

WHAT HAPPENS:
The process runs in 6 stages:
1. Prechecks - Validates your email and gets device configuration
2. Rename Computer - Sets your device name (may require a reboot)
3. Miradore MDM - Installs mobile device management software
4. Bitdefender - Installs security software
5. Security Policies - Applies Windows security settings
6. Finalize - Completes enrollment and shows summary

IMPORTANT NOTES:
- Keep all files together in the same folder
- Don't delete anything - all files are required
- Your computer may restart during the process
- The process will resume automatically after any reboot
- Make sure you have a working internet connection before running the installer
- DO NOT close or quit the wizard at any stage - this may corrupt installations and cause system issues

BITDEFENDER INSTALLATION:
- Bitdefender opens in a separate window during installation
- You MUST complete the Bitdefender installation in that window
- Do NOT close the Bitdefender window until it finishes
- The main script will wait for Bitdefender to complete before continuing
- If you close Bitdefender early, the enrollment will fail

TROUBLESHOOTING:
- "File not found" error: Make sure all files are extracted to the same folder
- Script won't run: Always use "run-enrollment.bat" - don't try to run files in the assets folder directly
- If you accidentally close the script: Don't worry - double click and run again. The script will continue from where it left off
- Bitdefender installation failed: Make sure you completed the Bitdefender installation in the separate window
- If any failure occurs: Try rerunning the script before contacting Teams Squared support
- WARNING: If you quit the wizard during installation, it may corrupt your system - always let it complete

WHAT GETS INSTALLED:
- Miradore MDM: Mobile device management for corporate security
- Bitdefender GravityZone: Enterprise antivirus and security
- Windows Security Policies: USB controls, firewall, and other security settings

AFTER ENROLLMENT:
Your device will be properly named, protected with enterprise security software,
managed by our IT team, and compliant with company security policies.
You can delete the enrollment wizard package folder once enrollment is complete.

SUPPORT:
If you need help, contact: cybersecurity@teamsquared.io
Include your device name, error message, and stage number.

Version: 1.0.3
Last Updated: 26-09-2025
