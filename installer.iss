; Teams Squared Device Enrollment Installer
; Inno Setup Script

#define MyAppName "Teams Squared Device Enrollment"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Teams Squared Pte. Ltd"
#define MyAppURL "https://teamsquared.io"
#define MyAppExeName "TS2-Enrollment-Setup.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId={{797B7679-DF58-45CF-87C7-B39508497DE9}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={commonappdata}\TS2\Wizard
DefaultGroupName=Teams Squared
AllowNoIcons=yes
LicenseFile=
OutputDir=dist
OutputBaseFilename=TS2-Enrollment-Setup
SetupIconFile=src\assets\icon.ico
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
WizardStyle=modern
WizardImageFile=
WizardSmallImageFile=
DisableProgramGroupPage=yes
DisableReadyPage=no
DisableFinishedPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main enrollment script
Source: "src\enroll.ps1"; DestDir: "{commonappdata}\TS2\Wizard"; Flags: ignoreversion

; Stage scripts
Source: "src\scripts\*"; DestDir: "{commonappdata}\TS2\Wizard\scripts"; Flags: recursesubdirs ignoreversion

; Assets (Miradore MSI and Bitdefender XML and EXE)
Source: "src\assets\mdm.msi"; DestDir: "{commonappdata}\TS2\Wizard\assets"; Flags: ignoreversion
Source: "src\assets\installer.xml"; DestDir: "{commonappdata}\TS2\Wizard\assets"; Flags: ignoreversion
Source: "src\assets\epskit_x64.exe"; DestDir: "{commonappdata}\TS2\Wizard\assets"; Flags: ignoreversion

; Icon files
Source: "src\assets\icon.ico"; DestDir: "{commonappdata}\TS2\Wizard\assets"; Flags: ignoreversion
Source: "src\assets\icon.png"; DestDir: "{commonappdata}\TS2\Wizard\assets"; Flags: ignoreversion

; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\Teams Squared\TS2 Enroll Device"; Filename: "powershell.exe"; Parameters: "-NoProfile -File ""{commonappdata}\TS2\Wizard\enroll.ps1"""; IconFilename: "{commonappdata}\TS2\Wizard\assets\icon.ico"
Name: "{group}\Teams Squared\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\TS2 Enroll Device"; Filename: "powershell.exe"; Parameters: "-NoProfile -File ""{commonappdata}\TS2\Wizard\enroll.ps1"""; Tasks: desktopicon; IconFilename: "{commonappdata}\TS2\Wizard\assets\icon.ico"

[UninstallDelete]
Type: filesandordirs; Name: "{commonappdata}\TS2\Wizard\state\*"
Type: filesandordirs; Name: "{commonappdata}\TS2\Wizard\config\*"

[Code]
procedure InitializeWizard();
begin
  WizardForm.Caption := 'Teams Squared Device Enrollment Setup';
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpWelcome then
  begin
    WizardForm.WelcomeLabel2.Caption := 'This wizard will install the Teams Squared Device Enrollment utility.' + #13#10 + #13#10 +
      'The enrollment wizard will:' + #13#10 +
      '• Rename your computer' + #13#10 +
      '• Install Miradore MDM client' + #13#10 +
      '• Install Bitdefender security agent' + #13#10 +
      '• Apply Windows security policies' + #13#10 + #13#10 +
      'Click Next to continue, or Cancel to exit Setup.';
  end
  else if CurPageID = wpFinished then
  begin
    WizardForm.FinishedLabel.Caption := 'Teams Squared Device Enrollment has been installed successfully.' + #13#10 + #13#10 +
      'NEXT STEPS:' + #13#10 +
      'Run the enrollment wizard from:' + #13#10 +
      '• Start Menu → Teams Squared → Enroll Device' + #13#10 +
      '• Desktop shortcut (if created)' + #13#10 + #13#10 +
      'Click Finish to complete the installation.';
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  if CurPageID = wpReady then
  begin
    WizardForm.ReadyMemo.Lines.Clear;
    WizardForm.ReadyMemo.Lines.Add('Setup is ready to install Teams Squared Device Enrollment on your computer.');
    WizardForm.ReadyMemo.Lines.Add('');
    WizardForm.ReadyMemo.Lines.Add('Click Install to continue with the installation.');
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Create necessary directories
    ForceDirectories(ExpandConstant('{commonappdata}\TS2\Wizard\config'));
    ForceDirectories(ExpandConstant('{commonappdata}\TS2\Wizard\state'));
    ForceDirectories(ExpandConstant('{commonappdata}\TS2\Wizard\state\logs'));
  end;
end;
