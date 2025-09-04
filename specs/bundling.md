# Bundling & Installer — Software Requirements Specification (SRS)

## 0. Overview

The Teams Squared Enrollment Wizard is delivered to contractors as a **single `.exe` installer** built with **Inno Setup**.
The installer must:

* Deploy all required scripts, assets, and configuration to a consistent location on disk.
* Create shortcuts and scheduled tasks needed for resume.
* Provide a clean, branded installer UX (v1: minimal Inno Setup default; v2: custom branding/UI).
* Ensure the wizard can run offline once installed (Miradore MSI and Bitdefender EXE embedded).

---

## 1. Installer contents

### 1.1 Extracted file tree

Installer expands to:

```
C:\ProgramData\TS2\Wizard\
  enroll.ps1
  scripts\
    prechecks.ps1
    rename.ps1
    miradore.ps1
    bitdefender.ps1
    policies.ps1
  config\
    config.json            # Downloaded separately by admin; not embedded
  state\
    state.json             # Created by wizard at runtime
    logs\
  assets\
    OnlineClientInstaller_teamssquared.msi
    epskit_x64.exe
```

### 1.2 Assets

* `OnlineClientInstaller_teamssquared.msi` (Miradore)
* `epskit_x64.exe` (Bitdefender)
  Embedded into installer and extracted at install time.

### 1.3 Generic vs per-device

* **Generic installer** (same for all contractors).
* Admin downloads per-device `config.json` separately and places it into `config\`.
* Wizard will not start without `config.json`.

---

## 2. Inno Setup configuration

### 2.1 Script basics (`installer.iss`)

* **AppName**: “Teams Squared Device Enrollment”
* **AppVersion**: 1.0.0
* **DefaultDirName**: `{commonappdata}\TS2\Wizard` (expands to `C:\ProgramData\TS2\Wizard`)
* **PrivilegesRequired**: admin (installer must run with elevation)
* **OutputDir**: `dist\` (build artifacts)
* **OutputBaseFilename**: `TS2-Enrollment-Setup`

### 2.2 Files section

```
[Files]
Source: "src\enroll.ps1"; DestDir: "{commonappdata}\TS2\Wizard"; Flags: ignoreversion
Source: "src\scripts\*"; DestDir: "{commonappdata}\TS2\Wizard\scripts"; Flags: recursesubdirs ignoreversion
Source: "src\assets\OnlineClientInstaller_teamssquared.msi"; DestDir: "{commonappdata}\TS2\Wizard\assets"; Flags: ignoreversion
Source: "src\assets\epskit_x64.exe"; DestDir: "{commonappdata}\TS2\Wizard\assets"; Flags: ignoreversion
```

### 2.3 Icons

```
[Icons]
Name: "{group}\Teams Squared\Enroll Device"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{commonappdata}\TS2\Wizard\enroll.ps1"""
```

* Creates a Start Menu shortcut under “Teams Squared” folder.
* Optional: desktop shortcut (toggle via `[Tasks]`).

### 2.4 Run after install

```
[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{commonappdata}\TS2\Wizard\enroll.ps1"""; Flags: nowait postinstall skipifsilent runascurrentuser
```

* Auto-launch wizard immediately after installation (if interactive).

### 2.5 Uninstall

* Uninstaller removes scripts/assets, but leaves `state\logs` for audit.

---

## 3. Branding & UX

### 3.1 v1 (minimum viable)

* Use default Inno Setup wizard UI.
* Set `AppName` and `AppVersion`.
* Use Teams Squared logo (if available) via `WizardImageFile`.
* Ensure texts are plain: “This wizard will install the Teams Squared Device Enrollment utility.”

### 3.2 v2 (enhanced UX)

* Replace default bitmap with **Teams Squared branding** (logo + color scheme).
* Use `WizardSmallImageFile` for a sidebar logo.
* Add custom **progress page** showing:

  * Current stage (1–6)
  * Status messages
  * Progress bar (manual update via Inno scripting, or hand-off to WinForms UI inside PowerShell)

In v2, when the wizard launches `enroll.ps1`, a **WinForms interface** will replace CLI logging, showing branded progress with:

* Title: “Teams Squared Device Enrollment”
* Subtitle: “Your device is being enrolled. Please keep it powered on.”
* Progress bar (stage-based, 6 steps).
* Text area with log messages.
* Cancel button (wired to Ctrl+C handler).

---

## 4. Security considerations

* **ExecutionPolicy**: always launched with `-ExecutionPolicy Bypass` (process-scoped, safe).
* **Elevation**: installer requires admin, so files land under `ProgramData` accessible to SYSTEM + local admins.
* **Config.json**: not bundled, must be downloaded separately with signed URL → prevents leaking JWTs inside public installers.
* **Logs**: persisted locally in `state\logs` but not exfiltrated unless wizard runs and calls API.

---

## 5. Workflow summary (admin & contractor)

### Admin side

1. In dashboard, admin clicks **+ Enroll Device** → record created in DB.
2. Admin clicks **Download Wizard** → gets generic `TS2-Enrollment-Setup.exe`.
3. Admin clicks **Download config.json** on a card → gets per-device JSON.
4. Admin ships `.exe` + `config.json` (same folder) with the hardware device.

### Contractor side

1. Run installer (requires admin).
2. Installer deploys wizard to `C:\ProgramData\TS2\Wizard\`.
3. Installer optionally launches wizard immediately.
4. Wizard finds `config.json` and executes enrollment stages.
5. Reboot (after rename) → scheduled task ensures resume.
6. Enrollment completes → logs pushed to server, task removed.

---

## 6. Acceptance criteria (bundling)

1. Running the installer places all files under `C:\ProgramData\TS2\Wizard\`.
2. Installer can be run silently with `/silent` (no GUI).
3. After install, a Start Menu shortcut exists to launch wizard manually.
4. Assets (Miradore MSI, Bitdefender EXE) are accessible locally and install offline.
5. Logs under `state\logs` are preserved after uninstall.
6. v2 branding: installer shows Teams Squared logo and custom messages.

---

## 7. Implementation notes

* **Build pipeline**:

  * Create `installer.iss` with file references.
  * Run Inno Setup Compiler → output `.exe`.
* **Static hosting**: place `.exe` under `/static/` route for dashboard download.
* **Versioning**: bump `AppVersion` in `.iss` on changes; embed in filename (e.g., `TS2-Enrollment-Setup-v1.0.1.exe`).
* **Icons**: supply `.ico` file for Start Menu icon.