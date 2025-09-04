# Admin Dashboard — Software Requirements Specification (SRS)

## 0. Overview

Build a single-page **React** dashboard (private deployment, same origin as API) to:

- Pre-enroll contractor devices by generating unique **device names** and persisting records.
- Capture **policy selections** per device (multiselect with mutual-exclusion logic).
- Provide **download links**:

  - A **generic installer** (`.exe`) for the Windows wizard (static asset).
  - A **per-device `config.json`** that includes a **24-hour, single-use JWT**, downloaded via a **time-limited signed URL**.

- Display a grid of **cards** for each `EnrollmentDevice` with status, timestamps, and any last error.

No login/auth for v1 (private network). No search/filter/edit/delete (v1). Uses **TailwindCSS** for styling and **lucide-react** for icons.

---

## 1. Naming & policy rules (business logic)

### 1.1 Device name construction (mirrors backend logic; shown here for UI expectations)

- Format: `TS2-Name-####`

  - `TS2` = prefix from `EnrollmentDeviceCounter.prefix` (server of record).
  - `Name` = derived from email local-part (before `@`):

    1. Strip all non-alphanumeric chars: `[^A-Za-z0-9]`.
    2. Lowercase, then capitalize first character only (e.g., `sam.k` → `Samk`).
    3. Truncate to **max 6 chars** (NetBIOS-safe total length).

  - `####` = left-padded with zeros to `padWidth` from counter row (e.g., `0005`).

- Final example: `TS2-Sam-0005`.
- **Server is source of truth** (the device name is ultimately generated in the transaction). The UI can preview, but must not persist a name without server confirmation.

### 1.2 Policies (IDs & descriptions)

Mutual exclusions are enforced in the UI (auto-unselect conflicting items with tooltip).

**Removable storage**

- **50 – USB storage: Read-only**
  Deny write to removable storage.
- **51 – USB storage: Block all**
  Deny all access to removable storage.
  **Conflicts with 50** (mutually exclusive).
- **52 – Block MTP/WPD (phones/cameras)**
  Deny Windows Portable Devices.

**Session/lock**

- **60 – Auto-lock after 10 minutes**
  Enforce secure lock + screensaver timeout.
- **61 – Hide last signed-in user**
  Do not display last username on logon screen.

**Network/host**

- **70 – Enable Windows Defender Firewall (all profiles)**
- **71 – Disable SMBv1**
- **72 – Force NLA for RDP (keep RDP enabled)**
- **73 – Disable RDP**
  **Conflicts with 72** (mutually exclusive).

**Updates**

- **80 – Windows Update: auto install (AUOptions=4)**

_(These IDs and descriptions must be used verbatim by UI and passed to server as selected list.)_

---

## 2. Information architecture & routes

### 2.1 Pages (single page app)

- **/enrollment** (default & only route in v1)

### 2.2 Layout

- **Header** (sticky): product + page title/subtitle.
- **Toolbar** (right-aligned inside header area):

  - **“+ Enroll Device”** button → opens modal.
  - **“Download Wizard”** button → downloads the **generic installer** `.exe`.

- **Content**:

  - **Grid of Device Cards** (responsive):

    - Pending (assigned=false), Completed (assigned=true), and Error states are visually distinct.
    - No filter/search in v1; cards are ordered `updatedAt DESC`.

---

## 3. Components (React, Tailwind, lucide-react)

> Suggested file structure:

```
src/
  components/
    Header.tsx
    Toolbar.tsx
    DeviceGrid.tsx
    DeviceCard.tsx
    EnrollModal.tsx
    PolicySelect.tsx
    ConfirmDialog.tsx
    Toast.tsx
  hooks/
    useEnrollmentApi.ts
    useSignedUrl.ts
  lib/
    policyCatalog.ts
    types.ts
  pages/
    EnrollmentPage.tsx
  app.tsx / main.tsx
```

### 3.1 `<Header />`

- **Purpose**: Display “Teams Squared” and “Device Enrollment”.
- **Tailwind**:

  - Wrapper: `w-full bg-white border-b`
  - Inner container: `mx-auto max-w-7xl px-6 py-4 flex items-center justify-between`

- **Content**:

  - Left:

    - Title: `text-xl font-semibold text-gray-900` → “Teams Squared”
    - Subtitle: `text-sm text-gray-500` → “Device Enrollment”

  - Right: `<Toolbar />`

### 3.2 `<Toolbar />`

- **Buttons**:

  - **+ Enroll Device**
    Tailwind: `inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700`
    Icon: `Plus` (lucide)
    Action: open `<EnrollModal />`
  - **Download Wizard**
    Tailwind: `ml-3 inline-flex items-center gap-2 rounded-lg bg-slate-100 px-4 py-2 text-slate-900 hover:bg-slate-200`
    Icon: `Download`
    Action: GET static `installer.exe` from same origin (e.g., `/static/TS2-Enrollment-Setup.exe`)

### 3.3 `<DeviceGrid />`

- **Purpose**: Render cards.
- **Props**: `devices: EnrollmentDevice[]`
- **Tailwind**: responsive grid
  `grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 p-6 max-w-7xl mx-auto`
- **Empty state**:
  Card with muted text: “No devices yet. Click **+ Enroll Device** to create one.”

### 3.4 `<DeviceCard />`

- **Data shown**:

  - `deviceName` (primary, bold)
  - `email`
  - **Status**:

    - **Pending**: `assigned=false` → icon `Clock` (amber) with “Pending”
    - **Completed**: `assigned=true` → icon `CheckCircle2` (green) with “Completed”
    - **Error**: if `lastErrorMessage` present → icon `TriangleAlert` (red) with “Attention”

  - **Timestamps**: `assignedAt`, `enrolledAt` (relative + tooltip full date)
  - **Policies**: small badges with ID numbers (and tooltip with names)
  - **Actions** (right/top or within card footer):

    - **Download config.json** (per-device; signed URL)
      Button: `inline-flex items-center gap-2 rounded-md border px-3 py-1.5 text-sm hover:bg-slate-50`
      Icon: `FileDown`

- **Tailwind**:

  - Wrapper: `rounded-xl border bg-white shadow-sm p-4 flex flex-col gap-3`
  - Header row: `flex items-center justify-between`
  - Title: `text-base font-semibold text-gray-900`
  - Meta: `text-sm text-gray-600`
  - Status pill:

    - Pending: `inline-flex items-center gap-1 rounded-full bg-amber-100 text-amber-800 px-2 py-0.5 text-xs`
    - Completed: `inline-flex items-center gap-1 rounded-full bg-emerald-100 text-emerald-800 px-2 py-0.5 text-xs`
    - Error: `inline-flex items-center gap-1 rounded-full bg-rose-100 text-rose-800 px-2 py-0.5 text-xs`

  - Policy badge: `rounded bg-slate-100 text-slate-800 px-1.5 py-0.5 text-[11px]`

**Download config action (flow):**

1. Click → call `/api/signed-url/config?id=<EnrollmentDevice.id>` (same origin).
2. API returns a **time-limited signed URL** (e.g., `/api/config/download?token=...`) that streams `config.json`:

   ```json
   {
     "apiBase": "http://localhost:5xxx",
     "enrollmentDeviceId": "<id>",
     "jwt": "<24h single-use token>",
     "expiresAt": "<ISO8601>"
   }
   ```

3. Browser navigates to the signed URL (download starts).
4. Show success toast “config.json downloaded.”

### 3.5 `<EnrollModal />`

- **Open from**: Toolbar button.

- **Fields**:

  - **Email** (`<input type="email">`)

    - Placeholder: `user@teamsquared.io`
    - Validation: domain must be `teamsquared.io`, format RFC-ish.

  - **Policies multiselect** (`<PolicySelect />`)

    - Checkbox list with descriptions, conflict detection.

- **Buttons**:

  - **Cancel** → close
  - **Add** → submit (enabled only when email valid)

- **Behavior on submit**:

  1. `POST /enroll/preassign` (server performs transaction: increment counter, build deviceName, insert pending record with `policyIdsCsv`, return row)
  2. On success: close modal, optimistic insert into grid (top).
  3. On failure: show error toast; do not close.

- **Tailwind**:

  - Overlay: `fixed inset-0 bg-black/30`
  - Modal: `fixed inset-0 flex items-center justify-center p-4`
  - Card: `w-full max-w-lg rounded-xl bg-white shadow-xl border`
  - Header: `px-6 pt-5 pb-2 text-lg font-semibold`
  - Body: `px-6 py-4 space-y-4`
  - Footer: `px-6 pb-5 pt-2 flex justify-end gap-3`

### 3.6 `<PolicySelect />`

- **Source**: `policyCatalog.ts` (export const POLICY_CATALOG = …)
- **UI**: checklist with label + small description.

  - Row: `flex items-start gap-3 p-2 rounded hover:bg-slate-50`
  - Checkbox: native input + custom styles
  - Name: `font-medium text-sm`
  - Description: `text-xs text-gray-600`
  - Conflict handling:

    - When selecting a policy, if conflicts exist:

      - Auto-unselect conflicts.
      - Show inline `title` tooltip on the conflicted item: “Cannot combine with X”.

- **Value**: returns `number[]` of selected IDs; the modal serializes to CSV before POST.

### 3.7 `<ConfirmDialog />`

- Used later (v2 UI) for dangerous actions; not needed v1 except perhaps for explanatory dialogs. Keep component present but unused.

### 3.8 Toasts

- **Success/Failure** ephemeral messages (top-right).
- Tailwind: container fixed `top-4 right-4 flex flex-col gap-2`
- Variants: green (success), red (error).

---

## 4. State management & data flow

### 4.1 Types (lib/types.ts)

```ts
export type EnrollmentDevice = {
  id: string;
  deviceName: string;
  email: string;
  assigned: boolean; // false=pending, true=completed
  policyIdsCsv?: string | null;
  lastErrorMessage?: string | null;
  lastErrorStage?: number | null;
  enrolledAt: string; // ISO
  assignedAt?: string | null; // ISO
  updatedAt: string; // ISO
};
```

### 4.2 API hooks

- `useEnrollmentApi`

  - `listDevices(): Promise<EnrollmentDevice[]>`
  - `preassign(email: string, policyIds: number[]): Promise<EnrollmentDevice>`
  - `getSignedConfigUrl(id: string): Promise<{ url: string }>`

- `useSignedUrl`

  - Handles click → fetch URL → triggers `window.location.href = url`.

### 4.3 Initial load

- On mount, call `listDevices()` → set local state.
- Cards render in **updatedAt DESC** order.

### 4.4 Creating a pre-enroll record

- In modal submit:

  - Validate email (`@teamsquared.io`), show inline error if invalid.
  - Serialize policies to CSV (`"50,60,71"`).
  - Disable submit while awaiting response; show small spinner on button (add `animate-spin` icon).
  - On success: close modal, prepend device into state (optimistic UI).
  - On error: show toast and keep the modal open.

### 4.5 Download config.json

- Card action calls `getSignedConfigUrl(id)`.
- If 200: set `window.location.href = url` to start download.
- If error: show toast; keep page state.

---

## 5. Visual design notes (Tailwind)

- **Colors**: neutral whites/grays with indigo accents for primary actions.
- **Spacing**: consistent `p-4` / `p-6`, grid gaps `gap-6`.
- **Typography**: system font stack, sizes `text-sm`, `text-base`, `text-xl` for headers.
- **Elevation**: `shadow-sm` for cards, `shadow-xl` for modal.
- **Radii**: `rounded-xl` default; pills/badges `rounded-full`.

Example policy badge:

```html
<span class="rounded bg-slate-100 text-slate-800 px-1.5 py-0.5 text-[11px]">
  50
</span>
```

---

## 6. Edge cases & validations

- **Email domain**: Must end with `@teamsquared.io`. UI rejects if not; helper text under the field.
- **Policy conflicts**:

  - Selecting **51** auto-unselects **50** (and vice versa).
  - Selecting **73** auto-unselects **72** (and vice versa).

- **Multiple devices per email**: Allowed; cards will show duplicates with distinct `deviceName`.
- **Race** (rare): If two admins click **Add** for the same user simultaneously:

  - Server serializes via transaction; UI simply renders both results. (No client action needed.)

- **Network errors**:

  - Show red toast “Network unavailable. Please try again.”

- **Installer download**:

  - Generic installer can be served as a static asset; handle 404 with toast.

---

## 7. Accessibility (A11y)

- Modal traps focus; ESC closes.
- Buttons have `aria-label`s alongside icon+text.
- Status icons include `aria-live` text (`Pending`, `Completed`, `Attention`).
- Color contrasts meet WCAG AA (use Tailwind defaults that do).

---

## 8. Performance & UX

- `listDevices` paginates server-side once the list exceeds a threshold (e.g., 60). For v1, simple fetch is fine.
- Avoid granular re-renders: key by `device.id`, derive `status` client-side.

---

## 9. Acceptance criteria (dashboard)

1. **Create pre-enrollment**

   - Given a valid `user@teamsquared.io` and policies, clicking **Add** creates a record, a card appears with **Pending** status, policies displayed as badges, and timestamps set.

2. **Conflict handling**

   - Selecting both 50 & 51 is impossible; selecting one unselects the other with tooltip notice. Same for 72 & 73.

3. **Download wizard (generic)**

   - Clicking **Download Wizard** retrieves a static `.exe` from the same origin.

4. **Download per-device config**

   - Clicking **Download config.json** on any card retrieves a file with `{ apiBase, enrollmentDeviceId, jwt, expiresAt }` via time-limited signed URL.

5. **Error visibility**

   - If a device later reports an error (via wizard), the card updates to show **Attention** with the last error message succinctly visible (first 80 chars) and full message on hover tooltip.

6. **No auth**

   - The dashboard loads on a private network without login prompts.

---

## 10. Implementation notes (developer enablement)

- **Libraries**:

  - `react`, `react-dom`, `lucide-react`, `axios` (or `fetch`), `clsx` (optional).
  - Tailwind with PostCSS; preconfigure `tailwind.config.js` and `@tailwind base; @tailwind components; @tailwind utilities;`.

- **Icons**:

  - `Plus`, `Download`, `CheckCircle2`, `Clock`, `TriangleAlert`, `FileDown`.

- **Time formatting**:

  - Use `Intl.DateTimeFormat` for exact timestamps in tooltips; relative “x minutes ago” optional.

- **Error handling**:

  - All API calls display a red toast on `!response.ok`; generic message: “Operation failed. Please try again.”

---

## 11. Policy catalog source (lib/policyCatalog.ts)

```ts
export type Policy = {
  id: number;
  name: string;
  description: string;
  conflictsWith?: number[];
};

export const POLICY_CATALOG: Policy[] = [
  {
    id: 50,
    name: "USB storage: Read-only",
    description: "Deny write to removable storage",
    conflictsWith: [51],
  },
  {
    id: 51,
    name: "USB storage: Block all",
    description: "Deny all removable storage access",
    conflictsWith: [50],
  },
  {
    id: 52,
    name: "Block MTP/WPD",
    description: "Block phones/cameras as portable devices",
  },
  {
    id: 60,
    name: "Auto-lock after 10 minutes",
    description: "Lock screen and require password on resume",
  },
  {
    id: 61,
    name: "Hide last signed-in user",
    description: "Do not display last username on logon",
  },
  {
    id: 70,
    name: "Enable Windows Firewall",
    description: "Turn on firewall for all profiles",
  },
  {
    id: 71,
    name: "Disable SMBv1",
    description: "Remove vulnerable SMBv1 protocol",
  },
  {
    id: 72,
    name: "RDP with NLA",
    description: "Require Network Level Authentication",
    conflictsWith: [73],
  },
  {
    id: 73,
    name: "Disable RDP",
    description: "Disable Remote Desktop",
    conflictsWith: [72],
  },
  {
    id: 80,
    name: "Windows Update: Auto install",
    description: "Configure AUOptions=4 (auto install)",
  },
];
```

---

## 12. Security posture (dashboard scope)

- Dashboard and API are **same origin**; config/routes not publicly advertised.
- The **installer** is a static asset; access to the static route can be protected by a **time-limited signed URL** (optional) or private network.
- The **config.json** is **always** delivered via a **time-limited signed URL** (required).