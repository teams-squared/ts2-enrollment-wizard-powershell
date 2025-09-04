# Teams Squared Device Enrollment Wizard
# Main orchestrator script that manages the 6-stage enrollment process

param(
  [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths
$script:WizardRoot = "C:\ProgramData\TS2\Wizard"
$script:ConfigPath = Join-Path $WizardRoot "config\config.json"
$script:StatePath = Join-Path $WizardRoot "state\state.json"
$script:LogPath = Join-Path $WizardRoot "state\logs\wizard-$(Get-Date -Format 'yyyyMMdd').log"

# Ensure directories exist
$null = New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force
$null = New-Item -ItemType Directory -Path (Split-Path $StatePath) -Force

# Global variables
$script:Config = $null
$script:State = $null
$script:ApiBase = $null
$script:EnrollmentCompleted = $false

function Write-Log {
  param(
    [string]$Message,
    [string]$Level = "INFO",
    [int]$Stage = 0
  )
    
  $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
  $logEntry = @{
    timestamp = $timestamp
    stage     = $Stage
    level     = $Level
    message   = $Message
  } | ConvertTo-Json -Compress
    
  Add-Content -Path $script:LogPath -Value $logEntry
    
  if ($Verbose -or $Level -eq "ERROR") {
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } else { "White" })
  }
}

function Invoke-ApiCall {
  param(
    [string]$Endpoint,
    [string]$Method = "POST",
    [hashtable]$Body = @{},
    [string]$JWT = $null
  )
    
  try {
    $headers = @{
      "Content-Type" = "application/json"
    }
        
    if ($JWT) {
      $headers["Authorization"] = "Bearer $JWT"
    }
        
    $uri = "$script:ApiBase$Endpoint"
    $jsonBody = $Body | ConvertTo-Json -Compress
        
    Write-Log "API Call: $Method $uri" "INFO" 0
        
    $response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -Body $jsonBody -ErrorAction Stop
    
    # Check for backend error responses
    if ($response.error) {
      throw "Backend error: $($response.error)"
    }
        
    return $response
  }
  catch {
    Write-Log "API call failed: $($_.Exception.Message)" "ERROR" 0
    throw
  }
}

# Load configuration
function Get-Config {
  try {
    # Try multiple config.json locations for user convenience
    $configLocations = @(
      $script:ConfigPath,                                   # Standard location: C:\ProgramData\TS2\Wizard\config\config.json
      (Join-Path (Split-Path $PSScriptRoot) "config.json"), # Next to installer (one level up)
      (Join-Path $env:USERPROFILE "Downloads\config.json")  # User's Downloads folder
    )
    
    $foundConfig = $null
    foreach ($location in $configLocations) {
      if (Test-Path $location) {
        $foundConfig = $location
        Write-Log "Found config.json at: $location" "INFO" 0
        break
      }
    }
    
    if (-not $foundConfig) {
      throw "Config file not found. Searched locations:`n$($configLocations -join "`n")`n`nPlease place config.json in one of these locations."
    }
    
    # Copy config to standard location if not already there
    if ($foundConfig -ne $script:ConfigPath) {
      $null = New-Item -ItemType Directory -Path (Split-Path $script:ConfigPath) -Force
      Copy-Item -Path $foundConfig -Destination $script:ConfigPath -Force
      Write-Log "Config copied to standard location: $script:ConfigPath" "INFO" 0
    }
        
    $configContent = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
    $script:Config = $configContent
    $script:ApiBase = $configContent.apiBase
        
    Write-Log "Configuration loaded successfully" "INFO" 0
    Write-Log "API Base: $script:ApiBase" "INFO" 0
    Write-Log "Device ID: $($configContent.enrollmentDeviceId)" "INFO" 0
  }
  catch {
    Write-Log "Failed to load configuration: $($_.Exception.Message)" "ERROR" 0
    throw
  }
}

# Load state
function Get-State {
  try {
    if (Test-Path $script:StatePath) {
      $stateContent = Get-Content -Path $script:StatePath -Raw | ConvertFrom-Json
      $script:State = $stateContent
      Write-Log "State loaded: Current stage $($script:State.currentStage)" "INFO" 0
    }
    else {
      # Initialize new state
      $script:State = @{
        deviceId        = $script:Config.enrollmentDeviceId
        deviceName      = $null
        currentStage    = 1
        completedStages = @()
        cancelled       = $false
        lastError       = $null
        rebootScheduled = $false
      }
      Write-Log "New state initialized" "INFO" 0
    }
  }
  catch {
    Write-Log "Failed to load state: $($_.Exception.Message)" "ERROR" 0
    throw
  }
}

# Save state
function Save-State {
  try {
    $script:State | ConvertTo-Json -Depth 3 | Set-Content -Path $script:StatePath
    Write-Log "State saved successfully" "INFO" 0
  }
  catch {
    Write-Log "Failed to save state: $($_.Exception.Message)" "ERROR" 0
  }
}

# Report error to API
function Send-ErrorReport {
  param(
    [int]$Stage,
    [string]$ErrorMessage,
    [bool]$Critical = $true
  )
    
  try {
    $body = @{
      deviceId     = $script:State.deviceId
      stage        = $Stage
      errorMessage = $ErrorMessage
    }
        
    Invoke-ApiCall -Endpoint "/enroll/error" -Body $body -JWT $script:Config.jwt
    Write-Log "Error reported to API: $ErrorMessage" "ERROR" $Stage
  }
  catch {
    $apiError = "Failed to report error to API: $($_.Exception.Message)"
    Write-Log $apiError "ERROR" $Stage
    
    if ($Critical) {
      throw $apiError
    }
  }
}

# Log to API
function Send-LogEntry {
  param(
    [int]$Stage,
    [string]$Level,
    [string]$Message
  )
    
  try {
    $body = @{
      deviceId = $script:State.deviceId
      stage    = $Stage
      level    = $Level
      message  = $Message
    }
        
    Invoke-ApiCall -Endpoint "/enroll/log" -Body $body -JWT $script:Config.jwt
  }
  catch {
    Write-Log "Failed to log to API: $($_.Exception.Message)" "ERROR" $Stage
  }
}

# Execute stage
function Invoke-Stage {
  param(
    [int]$StageNumber,
    [string]$ScriptName
  )
    
  try {
    Write-Log "Starting Stage ${StageNumber}: ${ScriptName}" "INFO" $StageNumber
    $null = Send-LogEntry -Stage $StageNumber -Level "INFO" -Message "Starting stage $StageNumber"
        
    $scriptPath = Join-Path $script:WizardRoot "scripts\$ScriptName"
        
    if (-not (Test-Path $scriptPath)) {
      throw "Stage script not found: $scriptPath"
    }
        
    # Execute the stage script with live objects
    & $scriptPath -Config $script:Config -State $script:State -ApiBase $script:ApiBase -JWT $script:Config.jwt
    
    # Capture exit code immediately
    $exitCode = $LASTEXITCODE
    # Check exit code from script
    if ($exitCode -ne 0) {
      throw "Stage script failed with exit code: $exitCode"
    }
    
    # If the stage succeeded, persist the (now mutated) state
    Save-State
        
    # Mark stage as completed
    if ($script:State.completedStages -notcontains $StageNumber) {
      $script:State.completedStages += $StageNumber
    }
        
    Write-Log "Stage $StageNumber completed successfully" "INFO" $StageNumber
    $null = Send-LogEntry -Stage $StageNumber -Level "INFO" -Message "Stage $StageNumber completed successfully"
        
    return $true
  }
  catch {
    $errorMessage = "Stage $StageNumber failed: $($_.Exception.Message)"
    Write-Log $errorMessage "ERROR" $StageNumber
    
    try {
      $null = Send-LogEntry -Stage $StageNumber -Level "ERROR" -Message $errorMessage
      $null = Send-ErrorReport -Stage $StageNumber -ErrorMessage $errorMessage
    }
    catch {
      Write-Log "Failed to report stage failure to API: $($_.Exception.Message)" "ERROR" $StageNumber
    }
        
    $script:State.lastError = $errorMessage
    Save-State
        
    return $false
  }
}

# Handle cancellation
function Stop-Enrollment {
  # Don't log as error if enrollment completed successfully
  if ($script:EnrollmentCompleted) {
    Write-Log "Enrollment completed successfully - normal exit" "INFO" 6
    return
  }
  
  Write-Host "`nEnrollment cancelled by user." -ForegroundColor Yellow
  Write-Log "Enrollment cancelled by user" "ERROR" $script:State.currentStage
    
  try {
    Send-ErrorReport -Stage $script:State.currentStage -ErrorMessage "Manually terminated" -Critical $false
    Send-LogEntry -Stage $script:State.currentStage -Level "ERROR" -Message "Enrollment cancelled by user"
  }
  catch {
    Write-Log "Failed to report cancellation to API" "ERROR" $script:State.currentStage
  }
    
  $script:State.cancelled = $true
  Save-State
    
  exit 1
}

# Main execution
function Start-Enrollment {
  try {
    Write-Host "Teams Squared Device Enrollment Wizard" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
        
    # Load configuration and state
    Get-Config
    Get-State
    
    # Reset reboot flag if we're resuming after a reboot
    if ($script:State.rebootScheduled -and $script:State.currentStage -gt 1) {
      Write-Host "Resuming enrollment after system reboot..." -ForegroundColor Cyan
      $script:State.rebootScheduled = $false
      Save-State
    }
        
    # Set up cancellation handler
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Stop-Enrollment }
        
    # Define stages
    $stages = @(
      @{ Number = 1; Script = "prechecks.ps1"; Name = "Prechecks" },
      @{ Number = 2; Script = "rename.ps1"; Name = "Rename Computer" },
      @{ Number = 3; Script = "miradore.ps1"; Name = "Miradore MDM" },
      @{ Number = 4; Script = "bitdefender.ps1"; Name = "Bitdefender" },
      @{ Number = 5; Script = "policies.ps1"; Name = "Windows Policies" },
      @{ Number = 6; Script = "finalize.ps1"; Name = "Finalize" }
    )
        
    # Execute stages
    foreach ($stage in $stages) {
      if ($script:State.completedStages -contains $stage.Number) {
        Write-Host "[Stage $($stage.Number)/6] $($stage.Name) - Already completed" -ForegroundColor Green
        continue
      }
            
      Write-Host "[Stage $($stage.Number)/6] Running $($stage.Name)..." -ForegroundColor Yellow
            
      $script:State.currentStage = $stage.Number
      Save-State
            
      $success = Invoke-Stage -StageNumber $stage.Number -ScriptName $stage.Script
            
      if (-not $success) {
        Write-Host "[Stage $($stage.Number)/6] FAILED" -ForegroundColor Red
        Write-Host "`nEnrollment failed at stage $($stage.Number): $($stage.Name)" -ForegroundColor Red
        Write-Host "Error: $($script:State.lastError)" -ForegroundColor Red
        Write-Host "Check logs at: $script:LogPath" -ForegroundColor Gray
        Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
      }
            
      Write-Host "[Stage $($stage.Number)/6] OK" -ForegroundColor Green
      
      # Check if a reboot is scheduled (set by rename stage)
      if ($script:State.rebootScheduled) {
        Write-Host "`nSystem reboot is scheduled. Stopping enrollment to prevent interruption." -ForegroundColor Yellow
        Write-Host "Enrollment will automatically resume after reboot." -ForegroundColor Cyan
        Write-Log "Enrollment paused due to scheduled system reboot" "INFO" $stage.Number
        
        # Give user time to read the message
        Write-Host "`nContinuing in 10 seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
        
        exit 0
      }
    }
        
    # Finalize
    Write-Host "`nEnrollment completed successfully!" -ForegroundColor Green
    Write-Log "Enrollment completed successfully" "INFO" 6
    
    # Set completion flag to prevent error logging on exit
    $script:EnrollmentCompleted = $true
        
    # Clean up
    if (Test-Path $script:StatePath) {
      Remove-Item -Path $script:StatePath -Force
    }
        
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  }
  catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR" 0
    Write-Host "`nFatal error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check logs at: $script:LogPath" -ForegroundColor Gray
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
  }
}

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Host "This script must be run as Administrator. Restarting with elevated privileges..." -ForegroundColor Yellow
  try {
    Start-Process PowerShell -ArgumentList "-NoProfile -File `"$PSCommandPath`"" -Verb RunAs
    exit
  }
  catch {
    Write-Host "`nFailed to restart with admin privileges: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run this script as Administrator manually." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
  }
}

# Start the enrollment process
Start-Enrollment
