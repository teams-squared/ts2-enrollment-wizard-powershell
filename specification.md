# Teams Squared Enrollment Wizard - Consolidated Script

## Stage 1: Prechecks

### What it does:

- Tests API connectivity to backend health endpoint
- Prompts user for Teams Squared email address
- Validates email format matches @teamsquared.io domain
- Calls API lookup endpoint with email address
- Retrieves device configuration from backend
- Displays device ID, name, and policy assignments
- Handles API errors (404, 401, network failures)
- Provides consistent [OK]/[FAIL] status messages

### Data structures used:

- `$ApiBase` - Backend API base URL (hardcoded)
- `$email` - User input email address
- `$deviceConfig` - API response object containing:
  - `deviceId` - Unique device identifier
  - `deviceName` - Assigned computer name
  - `policyIdsCsv` - Comma-separated policy IDs

### Functions implemented:

- `Get-ApiUrl()` - Constructs API URLs
- `Test-InternetConnection()` - Tests API health endpoint
- `Read-EnrollmentEmail()` - Prompts and validates email input
- `Get-DeviceConfiguration()` - Calls API lookup endpoint
- `Start-PrechecksStage()` - Orchestrates the entire prechecks process

### Error handling:

- Network connectivity failures
- Invalid email format validation
- API 404 (no pending enrollment found)
- API 401 (authentication failures)
- General API call failures

## Stage 2: Rename Computer

### What it does:

- Checks if computer is already renamed to target name
- Renames computer using Windows Rename-Computer cmdlet
- Creates scheduled task for post-reboot resume
- Schedules system reboot in 10 seconds
- Exits gracefully to allow reboot

### Data structures used:

- `$script:State.deviceName` - Target computer name from Stage 1
- `$script:State.rebootScheduled` - Flag indicating reboot is needed
- `$env:COMPUTERNAME` - Current computer name

### Functions implemented:

- `Set-ComputerName()` - Renames computer to target name
- `New-ResumeTask()` - Creates scheduled task for resume
- `Remove-ResumeTask()` - Removes scheduled task when done
- `Start-SystemReboot()` - Schedules system reboot
- `Start-RenameStage()` - Orchestrates the entire rename process

### Error handling:

- Computer rename failures
- Scheduled task creation failures
- Reboot scheduling failures
- Graceful handling of already-renamed computers

## Stage 3: Miradore MDM

### What it does:

- Installs Miradore MDM package using Windows Provisioning Package
- Waits for Miradore service to start after installation
- Verifies Miradore service is running properly
- Provides clear success/failure feedback

### Data structures used:

- `$MiradorePpkgPath` - Path to miradore.ppkg file (same directory as script)
- `$ServiceWaitTime` - Global variable for service startup wait time (20 seconds)
- `$ServiceTimeout` - Global variable for service startup timeout (120 seconds)
- `$MiradoreServiceName` - Miradore service name ("miradoreclient")

### Functions implemented:

- `Install-MiradoreClient()` - Installs PPKG package using Install-ProvisioningPackage
- `Test-MiradoreService()` - Verifies and starts Miradore service
- `Start-MiradoreStage()` - Orchestrates the entire Miradore installation process

### Error handling:

- Package file not found errors
- Provisioning package installation failures
- Service not found errors
- Service startup failures

## Stage 4: Bitdefender GravityZone

### What it does:

- Installs Bitdefender GravityZone agent using Windows executable
- Waits 30 seconds for service to be created after installation
- Verifies Bitdefender service is running with 2-minute timeout
- Provides clear success/failure feedback

### Data structures used:

- `$BitdefenderExePath` - Path to Bitdefender installer (same directory as script)
- `$BitdefenderServiceName` - Bitdefender service name ("EPSecurityService")
- `$ServiceTimeout` - Global variable for service startup timeout (120 seconds)
- `$ServiceWaitTime` - Global variable for initial service wait (20 seconds)
- `$elapsed` - Elapsed time counter for service startup

### Functions implemented:

- `Install-BitdefenderAgent()` - Installs Bitdefender using Start-Process
- `Test-BitdefenderService()` - Verifies and waits for Bitdefender service
- `Start-BitdefenderStage()` - Orchestrates the entire Bitdefender installation process

### Error handling:

- Installer file not found errors
- Installation process failures
- Service not found errors
- Service startup timeout failures

## Stage 5: Windows Policies

### What it does:

- Parses policy IDs from CSV string in shared state
- Applies Windows security policies based on policy IDs
- Updates group policy to enforce changes
- Provides success/failure count for applied policies

### Data structures used:

- `$script:State.policyIdsCsv` - Comma-separated policy IDs from Stage 1
- `$policyIds` - Array of parsed policy IDs
- `$successCount` - Count of successfully applied policies
- `$totalCount` - Total number of policies to apply

### Functions implemented:

- `Get-PolicyIds()` - Parses CSV string into policy ID array
- `Set-Policy()` - Routes policy ID to appropriate setter function
- `Update-GroupPolicy()` - Forces group policy update
- `Start-PoliciesStage()` - Orchestrates the entire policies process

### Policy IDs supported:

- 50: USB Read-only policy
- 51: USB Block all policy
- 52: Block MTP/WPD policy
- 60: Auto-lock after 10 minutes
- 61: Hide last signed-in user
- 70: Enable Windows Firewall
- 80: Windows Update auto-install

### Error handling:

- Policy ID parsing failures
- Registry modification failures
- Group policy update failures
- Policy application failures

## Stage 6: Finalize

### What it does:

- Marks enrollment as complete in the backend API
- Displays comprehensive completion summary
- Shows device information and applied policies
- Provides final success confirmation

### Data structures used:

- `$script:State.deviceId` - Device ID from Stage 1
- `$script:State.deviceName` - Device name from Stage 1
- `$script:State.policyIdsCsv` - Applied policies from Stage 1
- `$ApiBase` - Backend API base URL

### Functions implemented:

- `Complete-Enrollment()` - Calls backend API to mark enrollment complete
- `Show-CompletionSummary()` - Displays final success summary
- `Start-FinalizeStage()` - Orchestrates the entire finalization process

### Error handling:

- Backend API completion failures
- Summary display failures
- Network connectivity issues

### Completion summary includes:

- Device name and ID
- Applied policies list
- Enrolled services (Miradore MDM, Bitdefender, Windows Policies)
- Thank you message

---

## API Logging & State Management

### What it does:

- Logs stage start/completion to backend API
- Reports errors to backend API for monitoring
- Tracks current stage and completed stages
- Handles API failures gracefully without stopping enrollment
- Provides comprehensive error reporting

### Data structures used:

- `$script:State.currentStage` - Current stage number (1-6)
- `$script:State.completedStages` - Array of completed stage numbers
- `$script:State.deviceId` - Device ID for API calls
- `$ApiBase` - Backend API base URL

### Functions implemented:

- `Invoke-ApiCall()` - Generic API call handler with error checking
- `Send-LogEntry()` - Logs stage events to backend API
- `Send-ErrorReport()` - Reports errors to backend API
- Stage tracking in each `Start-*Stage()` function

### API Endpoints used:

- `/wizard/lookup` - Get device configuration by email
- `/wizard/log` - Logs stage events and status
- `/wizard/error` - Reports stage failures and errors
- `/wizard/complete` - Marks enrollment as complete

### Error handling:

- API call failures don't stop enrollment process
- Graceful degradation when backend is unavailable
- Comprehensive error reporting for troubleshooting
- Non-critical API failures are logged but don't fail stages

---

## Error Messages & Color System

### What it does:

- Provides consistent visual feedback throughout enrollment process
- Uses standardized prefixes for different message types
- Color-codes messages for quick status identification
- Maintains professional appearance and user experience

### Message Prefixes:

- **`[OK]`** - Success messages (Green)
- **`[FAIL]`** - Failure/error messages (Red)
- **`[TRY AGAIN]`** - User input validation messages (Red)

### Color Coding System:

#### **Green Messages:**

- Successful operations
- Stage completions
- Service verifications
- Policy applications
- API connectivity confirmations

#### **Red Messages:**

- Failed operations
- Error conditions
- Service startup failures
- API call failures
- Invalid user input

#### **Yellow Messages:**

- Informational status updates
- Progress indicators
- Warning messages
- Non-critical notifications

#### **Cyan Messages:**

- Stage headers
- Important announcements
- Resume notifications
- System status updates

#### **White Messages:**

- General information
- Completion summaries
- Service lists
- Standard output

### Message Categories:

#### **Stage Headers:**

- Format: `"Running Stage X: [Stage Name]"`
- Color: Cyan
- Purpose: Clear stage identification

#### **Success Messages:**

- Format: `"  [OK] [Description]"`
- Color: Green
- Purpose: Confirm successful operations

#### **Error Messages:**

- Format: `"  [FAIL] [Description]"`
- Color: Red
- Purpose: Indicate failed operations

#### **User Input Messages:**

- Format: `"  [TRY AGAIN] [Description]"`
- Color: Red
- Purpose: Guide user input validation

#### **Progress Messages:**

- Format: `"  [Description]"`
- Color: Yellow
- Purpose: Show ongoing operations

### Error Message Examples:

```
[OK] API health endpoint reachable
[FAIL] Unable to connect to enrollment server
[TRY AGAIN] Please use a valid teamsquared.io email address
[OK] Computer renamed successfully
[FAIL] Unable to install Miradore MDM package
[OK] Miradore service is running
[FAIL] Bitdefender service failed to start within timeout period
[OK] Windows Firewall enabled for all profiles
[FAIL] Group policy update failed
[OK] Enrollment marked as complete in backend
```

### Consistency Guidelines:

- All function-level messages use 2-space indentation
- Success/failure prefixes are always `[OK]` or `[FAIL]`
- User input validation uses `[TRY AGAIN]` prefix
- Stage headers are always in Cyan
- Error messages are always in Red
- Success messages are always in Green
- Progress messages are always in Yellow
