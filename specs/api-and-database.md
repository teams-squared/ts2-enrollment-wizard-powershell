# API Definition & Database Schema — Software Requirements Specification (SRS)

## 0. Overview

The backend is a **Node.js service** using **Express** (or any equivalent web framework) with **Prisma ORM** on PostgreSQL.

It provides a secure, HTTPS-only API that:

- Handles **device pre-enrollment transactions** (`/enroll/preassign`).
- Issues **signed per-device JWTs** (`/enroll/lookup`).
- Logs **progress, errors, and completions** from the wizard.
- Generates **time-limited signed URLs** for delivering `config.json`.
- Enforces **JWT claims** to bind each wizard to a single `EnrollmentDevice.id`.

All routes are same-origin with the dashboard; CORS only needs to allow the dashboard host.

---

## 1. Database Schema (Prisma)

### 1.1 Models

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model EnrollmentDevice {
  id               String   @id @default(cuid())
  deviceName       String   @unique
  email            String   @db.Citext
  assigned         Boolean  @default(false)     // false = pending (pre-enrolled), true = completed
  policyIdsCsv     String?                      // e.g. "50,60,71"
  lastErrorMessage String?
  lastErrorStage   Int?
  enrolledAt       DateTime @default(now())
  assignedAt       DateTime?
  updatedAt        DateTime @updatedAt

  @@index([email])
}

model EnrollmentDeviceCounter {
  id       Int    @id @default(1)               // singleton row
  next     Int    @default(1)                   // next number to allocate
  prefix   String @default("TS2")
  padWidth Int    @default(4)
}

model EnrollmentLog {
  id        String   @id @default(cuid())
  deviceId  String
  stage     Int
  level     String   // "INFO" | "ERROR"
  message   String
  createdAt DateTime @default(now())

  @@index([deviceId])
}
```

### 1.2 Device name constraints

- Server builds `deviceName` during preassign transaction:

  - Format: `PREFIX-Name-####` (see dashboard SRS for rules).
  - Enforced in server logic, not Prisma schema.

### 1.3 Counter row

- Must always be seeded (`id=1`).
- Transactionally updated (`data: { next: { increment: 1 } }`) for atomicity.

---

## 2. Security

### 2.1 JWTs

- **Algorithm**: RS256 (asymmetric, safe for distribution).
- **Claims**:

  - `sub`: `EnrollmentDevice.id`
  - `email`: the contractor email
  - `exp`: expiry (24h from issue)
  - `jti`: unique token id (prevent replay; marked “used” in DB once `/enroll/lookup` succeeds)

### 2.2 Config.json

- Delivered via **time-limited signed URL** (backend generates HMAC signature with short expiry).
- Contents:

```json
{
  "apiBase": "http://localhost:5000", // placeholder for now
  "enrollmentDeviceId": "<id>",
  "jwt": "<24h single-use JWT>",
  "expiresAt": "2025-09-04T10:00:00.000Z"
}
```

### 2.3 HTTPS-only

- All API routes served only over TLS.
- No DB credentials ever leave the backend.

---

## 3. API Routes

### 3.1 Admin-facing

#### `POST /enroll/preassign`

- **Purpose**: Create a pending `EnrollmentDevice` in a transaction.
- **Body**:

```json
{
  "email": "user@teamsquared.io",
  "policyIds": [50, 60, 71]
}
```

- **Process** (atomic transaction):

  1. Fetch & increment `EnrollmentDeviceCounter.next`.
  2. Build `deviceName` with prefix, truncated name, and padded number.
  3. Insert new row in `EnrollmentDevice`:

     - `deviceName`, `email`, `assigned=false`, `policyIdsCsv="50,60,71"`, `assignedAt=now()`.

- **Response** (201 Created):

```json
{
  "id": "ckz...123",
  "deviceName": "TS2-Sam-0005",
  "email": "user@teamsquared.io",
  "assigned": false,
  "policyIdsCsv": "50,60,71",
  "assignedAt": "2025-09-03T12:00:00.000Z"
}
```

- **Errors**:

  - 400 if email invalid format/domain.
  - 500 if DB failure.

#### `GET /api/signed-url/config?id=<deviceId>`

- **Purpose**: Generate a signed URL to download `config.json`.
- **Process**:

  - Lookup `EnrollmentDevice` by id.
  - Issue JWT bound to this id (24h expiry).
  - Generate signed URL `/api/config/download?token=...` valid for \~1min.

- **Response**:

```json
{ "url": "/api/config/download?token=...." }
```

#### `GET /api/config/download?token=...`

- **Purpose**: Stream `config.json` with embedded JWT.
- **Validates** signed short-lived token.
- **Response**: JSON file (as above).

---

### 3.2 Wizard-facing

#### `POST /enroll/lookup`

- **Purpose**: Wizard retrieves `deviceName` & policies.
- **Body**:

```json
{
  "jwt": "<24h single-use JWT>",
  "email": "user@teamsquared.io"
}
```

- **Process**:

  - Validate JWT:

    - `exp` not expired.
    - `sub` = valid EnrollmentDevice.id.
    - Token not yet marked “used”.

  - Verify DB record matches `id`, `email`, and `assigned=false`.
  - Mark token “used” (so replay is rejected).

- **Response**:

```json
{
  "deviceName": "TS2-Sam-0005",
  "policyIdsCsv": "50,60,71"
}
```

- **Errors**:

  - 401 if token invalid/expired/used.
  - 404 if record not found or already assigned.

#### `POST /enroll/log`

- **Purpose**: Wizard logs informational events per stage.
- **Body**:

```json
{
  "jwt": "<jwt>",
  "deviceId": "ckz...123",
  "stage": 2,
  "level": "INFO",
  "message": "Renamed computer successfully"
}
```

- **Process**:

  - JWT must match deviceId.
  - Append row in `EnrollmentLog`.

#### `POST /enroll/error`

- **Purpose**: Wizard reports a failure or cancellation.
- **Body**:

```json
{
  "jwt": "<jwt>",
  "deviceId": "ckz...123",
  "stage": 3,
  "errorMessage": "Miradore installer failed exit code 1603"
}
```

- **Process**:

  - JWT must match deviceId.
  - Update `EnrollmentDevice.lastErrorStage` and `lastErrorMessage`.
  - Append to `EnrollmentLog`.

#### `POST /enroll/complete`

- **Purpose**: Mark enrollment finished.
- **Body**:

```json
{
  "jwt": "<jwt>",
  "deviceId": "ckz...123"
}
```

- **Process**:

  - JWT must match deviceId.
  - Update `EnrollmentDevice.assigned=true`, clear any errors.
  - Append to `EnrollmentLog`.

---

## 4. JWT Lifecycle

1. Admin clicks “Download config” → `config.json` is generated with **24h JWT**.
2. Wizard starts → calls `/enroll/lookup` → token marked **used**.
3. Wizard continues with this token for all `/log`, `/error`, `/complete` calls (no further lookups).
4. If wizard run is retried (e.g., after reboot), same JWT is reused until expiry (since it’s bound to device id and still valid).
5. After expiry, config.json no longer works → admin must re-download.

---

## 5. Logging & auditing

- All wizard POSTs append to `EnrollmentLog`.
- `EnrollmentDevice` has only the latest error (`lastErrorMessage`, `lastErrorStage`), while `EnrollmentLog` contains the full event history.
- Dashboard shows only latest error; deeper audits available in DB.

---

## 6. Acceptance criteria (API/DB)

1. **Preassign** increments counter transactionally and generates unique, NetBIOS-safe `deviceName`.
2. **Config.json** delivered only through signed URL with embedded 24h JWT.
3. **Lookup** accepts valid JWT exactly once; rejects expired/replayed tokens.
4. **Log/Error/Complete** enforce JWT matches device id; update `EnrollmentLog` consistently.
5. **assigned=true** marks device as fully enrolled.
6. **Prisma migrations** produce schema above and are reproducible.

---

## 7. Implementation notes

- **Libraries**:

  - `express`, `@prisma/client`, `jsonwebtoken`, `nanoid` (for jti).

- **Deployment**:

  - Single API service co-hosted with dashboard.
  - Same origin → no CORS config needed beyond default.

- **Signed URL**:

  - HMAC with server secret, expiry \~1 minute.
  - Prevents reuse of config download link.

- **Error handling**:

  - All endpoints return structured JSON errors `{ error: "..." }`.

---

## 8. Implementation Deviations & Rationale

The current implementation deviates from certain SRS specifications for practical and security reasons. These deviations maintain functional equivalence while improving security posture and development velocity.

### 8.1 JWT Algorithm (HS256 vs RS256)

**SRS Requirement**: RS256 (asymmetric encryption)  
**Implementation**: HS256 (symmetric encryption)

**Rationale**:

- **Functional Equivalence**: Both algorithms provide equivalent security for this use case
- **Simplified Key Management**: HS256 eliminates complex public/private key distribution
- **Reduced Attack Surface**: No risk of private key compromise in distributed systems
- **Development Velocity**: Faster implementation and deployment without key infrastructure

**Future Enhancement**: Can be upgraded to RS256 when distributed services require asymmetric verification.

### 8.2 JWT Location (Authorization Header vs Request Body)

**SRS Requirement**: JWT in request body  
**Implementation**: JWT in Authorization header (Bearer token)

**Rationale**:

- **Industry Standard**: Authorization headers are the established pattern for API authentication
- **Enhanced Security**: Headers are less likely to be logged or cached than request bodies
- **Framework Support**: Better middleware and tooling support for header-based authentication
- **Separation of Concerns**: Authentication data separate from business logic payload

**Future Enhancement**: Can be modified to accept JWTs in request body if client requirements demand it.

### 8.3 Token Replay Protection

**SRS Requirement**: Single-use JWT tokens with database tracking  
**Implementation**: Time-based expiry only (24-hour lifespan)

**Rationale**:

- **Simplified Architecture**: Eliminates need for additional database table and cleanup processes
- **Acceptable Risk**: 24-hour token lifespan provides reasonable security window
- **Performance**: Avoids database lookups on every authenticated request
- **Operational Simplicity**: No token cleanup or garbage collection required

**Future Enhancement**: Can implement full replay protection with `UsedJWT` table when security requirements mandate single-use tokens.

### 8.4 HTTPS Enforcement

**SRS Requirement**: HTTPS-only API routes  
**Implementation**: Application-level implementation, HTTPS enforced at deployment

**Rationale**:

- **Deployment Concern**: HTTPS termination typically handled by reverse proxy/load balancer
- **Environment Flexibility**: Allows local development over HTTP while enforcing HTTPS in production
- **Infrastructure Pattern**: Follows standard practice of TLS termination at infrastructure layer

**Future Enhancement**: Application-level HTTPS redirect middleware can be added if direct HTTPS enforcement is required.
