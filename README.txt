Teams Squared Device Enrollment
==============================

This package will automatically configure your Windows device for our corporate environment.

QUICK START:
1. Extract all files to a folder on your desktop
2. Double-click "run-enrollment.bat" (as Administrator)
3. Follow the prompts - you'll need your Teams Squared email address
4. Watch the video guide: https://www.loom.com/share/c0fadba382be47c5b4eda2ddeab49375?sid=f14ba22e-f6b1-4ebe-adca-c57a40a32a84

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
- You'll need to enter your email address again after any restart
- Make sure you have a working internet connection before running the installer
- DO NOT close or quit the wizard at any stage - this may corrupt installations and cause system issues

BITDEFENDER INSTALLATION:
- Bitdefender opens in a separate window during installation
- You MUST complete the Bitdefender installation in that window
- Do NOT close the Bitdefender window until it finishes
- The main script will wait for Bitdefender to complete before continuing
- If you close Bitdefender early, the enrollment will fail

FREQUENTLY ASKED QUESTIONS:

Q: I get a "File not found" error. What should I do?
A: Make sure all files are extracted to the same folder. Don't move or delete any files.

Q: The script won't run. What's wrong?
A: Always use "run-enrollment.bat" - don't try to run files in the assets folder directly. Right-click and "Run as administrator" if needed.

Q: I accidentally closed the script. Is that bad?
A: Don't worry - double click and run again. The script will continue from where it left off.

Q. Miradore MDM installation failed. What do I do?
A. Try restarting your PC, then run the enrollment script again. The script will continue from where it left off.

Q: Bitdefender installation failed. What happened?
A: Make sure you completed the Bitdefender installation in the separate window. Don't close that window until it finishes.

Q: The wizard seems stuck or frozen. What should I do?
A: Be patient - some stages take longer than others. If it's been more than 10 minutes without progress, try rerunning the script.

Q: After my PC restarted, nothing is happening. Is this normal?
A: Yes, it may take 1-2 minutes for the wizard to restart after the PC restarts. Please be patient and don't close any windows.

Q: Something went wrong. Who should I contact?
A: Try rerunning the script first. If it still fails, contact cybersecurity@teamsquared.io with your device name, error message, and stage number.

Q: Can I quit the wizard if I need to do something else?
A: NO! If you quit the wizard during installation, it may corrupt your system. Always let it complete - it will resume automatically after any reboot.

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
