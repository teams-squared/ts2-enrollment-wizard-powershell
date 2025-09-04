# Teams Squared Device Enrollment — Master Specification

This document provides an overview of the **Teams Squared Device Enrollment system** and directs implementers to detailed specifications for each subsystem.

---

## 0. Purpose

The project delivers a complete pipeline for securely enrolling contractor devices into the Teams Squared environment. It ensures:

* Unique, NetBIOS-safe device naming.
* Automated enrollment into **Miradore MDM** and **Bitdefender GravityZone**.
* Enforced Windows policies for compliance (ISO-27001 alignment).
* Transparent logging and error reporting to a central backend.

---

## 1. System Components

### 1.1 Admin Dashboard (React + Tailwind)

* UI for **pre-enrollment** of devices.
* Displays device cards (pending, completed, error).
* Provides per-device **config.json** download with JWT.
* Provides link to generic installer (`.exe`).
  ➡️ See: **`Admin Dashboard SRS`**

---

### 1.2 Backend API + Database (Node + Express + Prisma + PostgreSQL)

* **Prisma schema**: `EnrollmentDevice`, `EnrollmentDeviceCounter`, `EnrollmentLog`.
* Routes for:

  * `/enroll/preassign` — transactional device creation.
  * `/enroll/lookup` — wizard fetch with per-device JWT.
  * `/enroll/log`, `/enroll/error`, `/enroll/complete`.
  * `/api/signed-url/config` — per-device signed config.json delivery.
    ➡️ See: **`API & Database SRS`**

---

### 1.3 PowerShell Wizard (CLI)

* Runs in 6 stages: Prechecks → Rename (reboot) → Miradore → Bitdefender → Policies → Finalize.
* Uses `config.json` to connect securely to API.
* Logs locally and remotely; persists `state.json` for resume after reboot.
* Applies selected Windows policies (USB restrictions, auto-lock, firewall, etc.).
  ➡️ See: **`PowerShell Scripts SRS`**

---

### 1.4 Bundling & Installer (Inno Setup)

* Produces a single **signed `.exe` installer**.
* Installs wizard + assets under `C:\ProgramData\TS2\Wizard\`.
* Embeds Miradore MSI and Bitdefender EXE.
* Ships as **generic installer**; per-device `config.json` is downloaded separately.
* v1: default Inno UI; v2: branded UI with progress bar.
  ➡️ See: **`Bundling & Installer SRS`**

---

## 2. Data Flow Summary

1. **Admin** creates device in dashboard → backend generates unique `deviceName` and DB record.
2. Admin downloads:

   * Generic installer (`.exe`).
   * Per-device `config.json` (24h JWT).
3. **Contractor** runs installer → wizard executes enrollment stages.
4. Wizard logs progress and errors to API.
5. On completion, device record is marked `assigned=true`.

---

## 3. Compliance & Security

* Device policies enforce ISO-27001-aligned controls not achievable solely via MDM.
* No database credentials in client; wizard communicates only via JWT-protected API.
* All API calls are HTTPS; JWTs expire in 24h and are bound to `EnrollmentDevice.id`.
* Local logs preserved for offline troubleshooting.

---

## 4. References

* **Admin Dashboard SRS** → `dashboard.md`
* **API & Database SRS** → `api-and-database.md`
* **PowerShell Scripts SRS** → `powershell.md`
* **Bundling & Installer SRS** → `bundling.md`