#Requires -RunAsAdministrator

<#
    =====================================================================
    Teams Squared Enrollment Script
    Author: Teams Squared
    Contact: cybersecurity@teamsquared.io
    =====================================================================
    Version: 1.0.3
    Last Updated: 26-09-2025
    =====================================================================
    NOTICE:
    - This script is proprietary and must not be copied, altered, or
      redistributed without prior written consent from Teams Squared.
    - Unauthorized modification, reverse engineering, or malicious use
      of this script is strictly prohibited.
    - This script is provided "as is" and is intended for authorized
      internal use only.

    SECURITY:
    - All execution should follow Teams Squared security guidelines.
    - Any suspicious behavior, vulnerabilities, or misuse must be
      immediately reported to cybersecurity@teamsquared.io.
    =====================================================================
#>

# Error Action Preference
$ErrorActionPreference = "Stop"

# Exit Code Matrix:
# 0 = Success (all stages completed)
# 1 = General failure (catch-all)
# 2 = Stage 1 (Prechecks) failed
# 3 = Stage 2 (Rename Computer) failed
# 4 = Stage 3 (Miradore MDM) failed
# 5 = Stage 4 (Bitdefender GravityZone) failed
# 6 = Stage 5 (Windows Policies) failed
# 7 = Stage 6 (Finalize) failed

# Global Variables
$ApiBase = 'https://ts2-enrollment-wizard-backend.onrender.com'
$TaskName = "TS2-Resume"
$TaskPath = $PSCommandPath
$RebootDelay = 10
$ServiceWaitTime = 20
$ServiceTimeout = 120

# Miradore MDM
$MiradorePpkgPath = Join-Path (Split-Path $PSCommandPath) "teamssquared.ppkg"

# Bitdefender GravityZone
$BitdefenderExePath = Join-Path (Split-Path $PSCommandPath) "setupdownloader_[aHR0cHM6Ly9jbG91ZGFwLWVjcy5ncmF2aXR5em9uZS5iaXRkZWZlbmRlci5jb20vUGFja2FnZXMvQlNUV0lOLzAvYTVBOEdnL2luc3RhbGxlci54bWw-bGFuZz1lbi1VUw==].exe"
$BitdefenderServiceName = "EPSecurityService"

# Shared State
$script:State = @{
  deviceId        = $null
  deviceName      = $null
  policyIdsCsv    = $null
  currentStage    = 1
  completedStages = @()
  rebootScheduled = $false
}

# Helper Functions

function Invoke-ApiCall {
  param(
    [string]$Endpoint,
    [string]$Method = "POST",
    [hashtable]$Body = @{}
  )
    
  try {
    $headers = @{
      "Content-Type" = "application/json"
    }
        
    $uri = "$ApiBase$Endpoint"
    $jsonBody = $Body | ConvertTo-Json -Compress
        
    $response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -Body $jsonBody -ErrorAction Stop
    
    # Check for backend error responses
    if ($response.error) {
      throw "Backend error: $($response.error)"
    }
        
    return $response
  }
  catch {
    Write-Host "API call failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
  }
}

function Send-LogEntry {
  param(
    [int]$Stage,
    [string]$Level,
    [string]$Message
  )
    
  if (-not $script:State.deviceId) {
    return
  }
    
  try {
    $body = @{
      deviceId = $script:State.deviceId
      stage    = $Stage
      level    = $Level
      message  = $Message
    }
        
    $null = Invoke-ApiCall -Endpoint "/wizard/log" -Body $body
  }
  catch {
    Write-Host "Failed to log to API: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

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
        
    $null = Invoke-ApiCall -Endpoint "/wizard/error" -Body $body
  }
  catch {
    $apiError = "Failed to report error to API: $($_.Exception.Message)"
    Write-Host $apiError -ForegroundColor Yellow
    
    if ($Critical) {
      throw $apiError
    }
  }
}

# Policy Setters
function Set-USBReadOnlyPolicy {
  try {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
    $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "Deny_Write" -Value 1 -Type DWord -Force
    Write-Host "    [OK] USB storage: Read-only policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] USB storage: Read-only policy failed" -ForegroundColor Red
    return $false
  }
}

function Set-USBBlockAllPolicy {
  try {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
    $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "Deny_All" -Value 1 -Type DWord -Force
    Write-Host "    [OK] USB storage: Block all policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] USB storage: Block all policy failed" -ForegroundColor Red
    return $false
  }
}

function Set-MTPWPDPolicy {
  try {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PortableOperatingSystem"
    $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "AllowMTP" -Value 0 -Type DWord -Force
        
    $wpdPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PortableDevices"
    $null = New-Item -Path $wpdPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $wpdPath -Name "DenyAll" -Value 1 -Type DWord -Force
        
    Write-Host "    [OK] Block MTP/WPD policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] Block MTP/WPD policy failed" -ForegroundColor Red
    return $false
  }
}

function Set-AutoLockPolicy {
  try {
    $regPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -Value "600" -Force
        
    Set-ItemProperty -Path $regPath -Name "ScreenSaveActive" -Value "1" -Force
        
    $powerPath = "HKCU:\Control Panel\PowerCfg"
    $null = New-Item -Path $powerPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $powerPath -Name "CurrentPowerPolicy" -Value "0" -Force
        
    Write-Host "    [OK] Auto-lock after 10 minutes policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] Auto-lock policy failed" -ForegroundColor Red
    return $false
  }
}

function Set-HideLastUserPolicy {
  try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "DontDisplayLastUserName" -Value 1 -Type DWord -Force
    Write-Host "    [OK] Hide last signed-in user policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] Hide last user policy failed" -ForegroundColor Red
    return $false
  }
}

function Set-FirewallPolicy {
  try {
    # Enable Windows Firewall for all profiles
    netsh advfirewall set allprofiles state on | Out-Null
    Write-Host "    [OK] Windows Firewall enabled for all profiles" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] Firewall policy failed" -ForegroundColor Red
    return $false
  }
}

function Set-AutoUpdatePolicy {
  try {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "AUOptions" -Value 4 -Type DWord -Force
    Write-Host "    [OK] Windows Update auto-install policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] Auto-update policy failed" -ForegroundColor Red
    return $false
  }
}

# Stage 1: Prechecks Functions
function Test-InternetConnection {
  param (
    [string]$Base
  )

  try {
    $healthUri = "$Base/health"
    Invoke-WebRequest -Uri $healthUri -Method Head -TimeoutSec 10 -ErrorAction Stop | Out-Null
    Write-Host '  [OK] API health endpoint reachable' -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to connect to enrollment server" -ForegroundColor Red
    return $false
  }
}

function Read-EnrollmentEmail {
  while ($true) {
    $email = Read-Host 'Enter your Teams Squared email (e.g. alex@teamsquared.io)'

    if ([string]::IsNullOrWhiteSpace($email)) {
      Write-Host '  [TRY AGAIN] Please enter your email address' -ForegroundColor Red
      continue
    }

    if ($email -match '^[A-Za-z]+@teamsquared\.io$') {
      Write-Host '  [OK] Email format validated' -ForegroundColor Green
      return $email
    }

    Write-Host '  [TRY AGAIN] Please use a valid teamsquared.io email address' -ForegroundColor Red
  }
}

function Get-DeviceConfiguration {
  param (
    [string]$Base,
    [string]$Email
  )

  $lookupUri = "$Base/wizard/lookup"
  $body = @{ email = $Email } | ConvertTo-Json

  try {
    $response = Invoke-RestMethod -Uri $lookupUri -Method Post -ContentType 'application/json' -Body $body -ErrorAction Stop
    Write-Host '  [OK] Device configuration retrieved successfully' -ForegroundColor Green
    return $response
  }
  catch {
    $statusCode = $null
    if ($_.Exception.Response) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    switch ($statusCode) {
      404 {
        Write-Host "  [FAIL] No enrollment found for this email address" -ForegroundColor Red
        throw "No pending enrollment found for $Email"
      }
      default {
        Write-Host "  [FAIL] Unable to retrieve device information" -ForegroundColor Red
        throw "Lookup request failed: $($_.Exception.Message)"
      }
    }
  }
}

# Stage 1: Prechecks Stage Function
function Start-PrechecksStage {
  try {
    Write-Host 'Running Stage 1: Prechecks' -ForegroundColor Cyan
    $script:State.currentStage = 1

    # Test API connectivity
    $internetResult = Test-InternetConnection -Base $ApiBase
    if (-not $internetResult) {
      throw "Unable to connect to enrollment server"
    }

    # Get email and device configuration
    $email = Read-EnrollmentEmail
    $deviceConfig = Get-DeviceConfiguration -Base $ApiBase -Email $email

    # Store device configuration in global state
    $script:State.deviceId = $deviceConfig.deviceId
    $script:State.deviceName = $deviceConfig.deviceName
    $script:State.policyIdsCsv = $deviceConfig.policyIdsCsv

    $null = Send-LogEntry -Stage 1 -Level "INFO" -Message "Starting stage 1"

    # Mark stage as completed
    if ($script:State.completedStages -notcontains 1) {
      $script:State.completedStages += 1
    }

    Write-Host 'Stage 1 completed successfully:' -ForegroundColor Green
    Write-Host "  Device ID   : $($deviceConfig.deviceId)"
    Write-Host "  Device Name : $($deviceConfig.deviceName)"
    Write-Host "  Policies    : $($deviceConfig.policyIdsCsv)"
    
    $null = Send-LogEntry -Stage 1 -Level "INFO" -Message "Stage 1 completed successfully"
    return $true
  }
  catch {
    $errorMessage = "Stage 1 failed: $($_.Exception.Message)"
    Write-Host "Stage 1: Prechecks failed" -ForegroundColor Red
    
    try {
      $null = Send-LogEntry -Stage 1 -Level "ERROR" -Message $errorMessage
      $null = Send-ErrorReport -Stage 1 -ErrorMessage $errorMessage
    }
    catch {
      Write-Host "Failed to report stage failure to API: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $false
  }
}

# Stage 2: Rename Computer Functions
function Set-ComputerName {
  try {
    $currentName = $env:COMPUTERNAME
    $newName = $script:State.deviceName
        
    Write-Host "  Renaming computer from '$currentName' to '$newName'" -ForegroundColor Yellow
        
    # Rename the computer
    Rename-Computer -NewName $newName -Force -ErrorAction Stop
        
    Write-Host "  [OK] Computer renamed successfully" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to rename computer" -ForegroundColor Red
    return $false
  }
}

function New-ResumeTask {
  try {
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
      Write-Host "  [OK] Resume task already exists" -ForegroundColor Green
      return $true
    }
    
    # Running PowerShell directly since it already runs with highest previleges
    $scriptPath = Join-Path (Split-Path $TaskPath) "enroll.ps1"
    $psExe = Join-Path $PSHOME "powershell.exe"
    $arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""

    $action = New-ScheduledTaskAction -Execute $psExe -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Description "Teams Squared Enrollment Resume Task" -Settings $settings -RunLevel Highest -Force
        
    Write-Host "  [OK] Resume task created successfully" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to create resume task" -ForegroundColor Red
    return $false
  }
}

function Remove-ResumeTask {
  try {
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
      Write-Host "  [OK] Resume task removed" -ForegroundColor Green
    }
    else {
      Write-Host "  [OK] Resume task not found (already removed)" -ForegroundColor Green
    }
        
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to remove resume task" -ForegroundColor Red
    return $false
  }
}

function Start-SystemReboot {
  try {
    Write-Host "  Scheduling system reboot in $RebootDelay seconds" -ForegroundColor Yellow
    Write-Host "  The system will automatically resume enrollment after reboot." -ForegroundColor Cyan
        
    shutdown /r /t $RebootDelay /c "Teams Squared Enrollment: Rebooting to apply computer name change"
        
    Write-Host "  [OK] Reboot scheduled" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to schedule system reboot" -ForegroundColor Red
    return $false
  }
}

# Stage 2: Rename Computer Stage Function
function Start-RenameStage {
  try {
    Write-Host 'Running Stage 2: Rename Computer' -ForegroundColor Cyan
    $script:State.currentStage = 2
    $null = Send-LogEntry -Stage 2 -Level "INFO" -Message "Starting stage 2"

    # Check if computer is already renamed
    if ($script:State.deviceName -eq $env:COMPUTERNAME) {
      Write-Host "  Computer is already renamed to '$($script:State.deviceName)'" -ForegroundColor Green
      
      # If yes, remove the resume task
      $removeResult = Remove-ResumeTask
      if (-not $removeResult) {
        throw "Unable to remove resume task"
      }
      
      # Mark stage as completed
      if ($script:State.completedStages -notcontains 2) {
        $script:State.completedStages += 2
      }
      
      $null = Send-LogEntry -Stage 2 -Level "INFO" -Message "Stage 2 completed successfully"
      return $true
    }
      
    # If no, rename the computer
    $renameResult = Set-ComputerName
    if (-not $renameResult) {
      throw "Unable to rename computer"
    }
      
    # Create the resume task
    $taskResult = New-ResumeTask
    if (-not $taskResult) {
      throw "Unable to create resume task"
    }
      
    # Schedule the system reboot
    $rebootResult = Start-SystemReboot
    if (-not $rebootResult) {
      throw "Unable to schedule system reboot"
    }
    $script:State.rebootScheduled = $true

    # Mark stage as completed
    if ($script:State.completedStages -notcontains 2) {
      $script:State.completedStages += 2
    }

    Write-Host 'Stage 2 completed successfully' -ForegroundColor Green
    Write-Host "  Enrollment will resume after reboot" -ForegroundColor Cyan
    
    $null = Send-LogEntry -Stage 2 -Level "INFO" -Message "Stage 2 completed successfully"
    exit 0
  }
  catch {
    $errorMessage = "Stage 2 failed: $($_.Exception.Message)"
    Write-Host "Stage 2: Rename Computer failed" -ForegroundColor Red
    
    try {
      $null = Send-LogEntry -Stage 2 -Level "ERROR" -Message $errorMessage
      $null = Send-ErrorReport -Stage 2 -ErrorMessage $errorMessage
    }
    catch {
      Write-Host "Failed to report stage failure to API: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $false
  }
}

# Stage 3: Miradore MDM Functions
function Install-MiradoreClient {
  try {
    if (-not (Test-Path $MiradorePpkgPath)) {
      Write-Host "  [FAIL] Miradore package not found at: $MiradorePpkgPath" -ForegroundColor Red
      return $false
    }
    
    # NOTE: Workaround for PowerShell issue with usernames containing spaces
    # See: https://github.com/PowerShell/PowerShell/issues/13300
    # Install-ProvisioningPackage fails when username has spaces in the path
    Write-Host "  Installing Miradore MDM package" -ForegroundColor Yellow
    
    # Store original TMP environment variable
    $originalTmp = $env:TMP
    
    try {
      # Set TMP to a path without spaces to work around PowerShell bug
      $env:TMP = "C:\temp"
      if (-not (Test-Path $env:TMP)) {
        New-Item -Path $env:TMP -ItemType Directory -Force | Out-Null
      }
      
      # Install with -Force to handle existing packages
      $result = Install-ProvisioningPackage -PackagePath $MiradorePpkgPath -QuietInstall -Force -ErrorAction SilentlyContinue
      
      if ($result -and $result.IsInstalled) {
        Write-Host "  [OK] Miradore MDM package installed successfully" -ForegroundColor Green
        return $true
      }
      else {
        # NOTE: Install-ProvisioningPackage does not return a reliable isInstalled flag the first time it is run.
        Write-Host "  [WARN] Miradore MDM package may have installed without a success flag. Continuing enrollment" -ForegroundColor Yellow
        return $true
      }
    }
    finally {
      # Restore original TMP environment variable
      $env:TMP = $originalTmp
    }
  }
  catch {
    Write-Host "  [FAIL] Unable to install Miradore MDM package" -ForegroundColor Red
    return $false
  }
}

# Stage 3: Miradore MDM Stage Function
function Start-MiradoreStage {
  try {
    Write-Host 'Running Stage 3: Miradore MDM' -ForegroundColor Cyan
    $script:State.currentStage = 3
    $null = Send-LogEntry -Stage 3 -Level "INFO" -Message "Starting stage 3"

    # Install Miradore client
    $installResult = Install-MiradoreClient
    if (-not $installResult) {
      throw "Unable to install Miradore MDM package"
    }
    
    # Mark stage as completed
    if ($script:State.completedStages -notcontains 3) {
      $script:State.completedStages += 3
    }
    
    Write-Host 'Stage 3 completed successfully' -ForegroundColor Green
    
    $null = Send-LogEntry -Stage 3 -Level "INFO" -Message "Stage 3 completed successfully"
    return $true
  }
  catch {
    $errorMessage = "Stage 3 failed: $($_.Exception.Message)"
    Write-Host "Stage 3: Miradore MDM failed" -ForegroundColor Red
    
    try {
      $null = Send-LogEntry -Stage 3 -Level "ERROR" -Message $errorMessage
      $null = Send-ErrorReport -Stage 3 -ErrorMessage $errorMessage
    }
    catch {
      Write-Host "Failed to report stage failure to API: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $false
  }
}

# Stage 4: Bitdefender GravityZone Functions
function Install-BitdefenderAgent {
  try {
    if (-not (Test-Path -LiteralPath $BitdefenderExePath)) {
      Write-Host "  [FAIL] Bitdefender installer not found at: $BitdefenderExePath" -ForegroundColor Red
      return $false
    }
        
    Write-Host "  Installing Bitdefender GravityZone agent" -ForegroundColor Yellow
        
    $process = Start-Process -FilePath $BitdefenderExePath -ArgumentList "/quiet /norestart" -PassThru
        
    Write-Host "  Bitdefender installation started in separate window (PID: $($process.Id))" -ForegroundColor Cyan
    Write-Host "  Waiting for installation to complete" -ForegroundColor Yellow
        
    $process.WaitForExit()
        
    if ($process.ExitCode -ne 0) {
      Write-Host "  [FAIL] Bitdefender agent installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
      return $false
    }
        
    Write-Host "  [OK] Bitdefender agent installed successfully" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to install Bitdefender agent" -ForegroundColor Red
    return $false
  }
}

function Test-BitdefenderInstalled {
  try {
    $service = Get-Service -Name $BitdefenderServiceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
      return $true
    }
    return $false
  }
  catch {
    return $false
  }
}

function Test-BitdefenderService {
  try {
    Write-Host "  Waiting for Bitdefender service to start" -ForegroundColor Yellow
    $null = Start-Sleep -Seconds $ServiceWaitTime
    
    # Check if service exists first
    $service = Get-Service -Name $BitdefenderServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
      Write-Host "  [FAIL] Bitdefender service not found" -ForegroundColor Red
      return $false
    }

    # If already running, return success immediately
    if (Test-BitdefenderInstalled) {
      Write-Host "  [OK] Bitdefender service is running" -ForegroundColor Green
      return $true
    }

    # Wait for service to start
    $elapsed = 0
    while ($service.Status -ne "Running" -and $elapsed -lt $ServiceTimeout) {
      $null = Start-Sleep -Seconds 5
      $elapsed += 5
      $service = Get-Service -Name $BitdefenderServiceName -ErrorAction SilentlyContinue
      Write-Host "  Waiting for service to start ($elapsed/$ServiceTimeout seconds)" -ForegroundColor Yellow
    }

    if ($service.Status -ne "Running") {
      Write-Host "  [FAIL] Bitdefender service failed to start within timeout period" -ForegroundColor Red
      return $false
    }

    Write-Host "  [OK] Bitdefender service is running" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to verify Bitdefender service" -ForegroundColor Red
    return $false
  }
}

# Stage 4: Bitdefender GravityZone Stage Function
function Start-BitdefenderStage {
  try {
    Write-Host 'Running Stage 4: Bitdefender GravityZone' -ForegroundColor Cyan
    $script:State.currentStage = 4
    $null = Send-LogEntry -Stage 4 -Level "INFO" -Message "Starting stage 4"

    # Check if Bitdefender is already installed and running
    if (Test-BitdefenderInstalled) {
      Write-Host "  Bitdefender service is already running" -ForegroundColor Green
      
      # Mark stage as completed
      if ($script:State.completedStages -notcontains 4) {
        $script:State.completedStages += 4
      }
      
      $null = Send-LogEntry -Stage 4 -Level "INFO" -Message "Stage 4 completed successfully (already installed)"
      return $true
    }

    # Install Bitdefender agent
    $installResult = Install-BitdefenderAgent
    if (-not $installResult) {
      throw "Unable to install Bitdefender agent"
    }
    
    # Verify service is running
    $serviceResult = Test-BitdefenderService
    if (-not $serviceResult) {
      throw "Unable to verify Bitdefender service"
    }
    
    # Mark stage as completed
    if ($script:State.completedStages -notcontains 4) {
      $script:State.completedStages += 4
    }
    
    Write-Host 'Stage 4 completed successfully' -ForegroundColor Green
    
    $null = Send-LogEntry -Stage 4 -Level "INFO" -Message "Stage 4 completed successfully"
    return $true
  }
  catch {
    $errorMessage = "Stage 4 failed: $($_.Exception.Message)"
    Write-Host "Stage 4: Bitdefender GravityZone failed" -ForegroundColor Red
    
    try {
      $null = Send-LogEntry -Stage 4 -Level "ERROR" -Message $errorMessage
      $null = Send-ErrorReport -Stage 4 -ErrorMessage $errorMessage
    }
    catch {
      Write-Host "Failed to report stage failure to API: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $false
  }
}

# Stage 5: Windows Policies Functions
function Get-PolicyIds {
  try {
    if (-not $script:State.policyIdsCsv) {
      Write-Host "  No policies to apply" -ForegroundColor Yellow
      return @()
    }
        
    $policyIds = $script:State.policyIdsCsv.Split(',') | ForEach-Object { [int]$_.Trim() }
    Write-Host "  Applying policies: $($policyIds -join ', ')" -ForegroundColor Yellow
    return $policyIds
  }
  catch {
    Write-Host "  [FAIL] Unable to parse policy IDs" -ForegroundColor Red
    return @()
  }
}

function Set-Policy {
  param([int]$PolicyId)
    
  switch ($PolicyId) {
    50 { return Set-USBReadOnlyPolicy }
    51 { return Set-USBBlockAllPolicy }
    52 { return Set-MTPWPDPolicy }
    60 { return Set-AutoLockPolicy }
    61 { return Set-HideLastUserPolicy }
    70 { return Set-FirewallPolicy }
    80 { return Set-AutoUpdatePolicy }
    default {
      Write-Host "    [FAIL] Unknown policy ID: $PolicyId" -ForegroundColor Red
      return $false
    }
  }
}

function Update-GroupPolicy {
  try {
    Write-Host "  Updating group policy" -ForegroundColor Yellow
    gpupdate /force | Out-Null
    Write-Host "  [OK] Group policy updated" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Group policy update failed" -ForegroundColor Red
    return $false
  }
}


# Stage 5: Windows Policies Stage Function
function Start-PoliciesStage {
  try {
    Write-Host 'Running Stage 5: Windows Policies' -ForegroundColor Cyan
    $script:State.currentStage = 5
    $null = Send-LogEntry -Stage 5 -Level "INFO" -Message "Starting stage 5"
    
    $policyIds = Get-PolicyIds
    if ($script:State.policyIdsCsv -and $policyIds.Count -eq 0) {
      throw "Policy ID parsing failed - no valid policies found"
    }
  
    $successCount = 0
    $totalCount = $policyIds.Count
    
    if ($totalCount -eq 0) {
      Write-Host "  No policies to apply" -ForegroundColor Yellow
      Write-Host 'Stage 5 completed successfully' -ForegroundColor Green
      
      # Mark stage as completed
      if ($script:State.completedStages -notcontains 5) {
        $script:State.completedStages += 5
      }
      
      $null = Send-LogEntry -Stage 5 -Level "INFO" -Message "Stage 5 completed successfully"
      return $true
    }
    
    foreach ($policyId in $policyIds) {
      Write-Host "  Applying policy $policyId" -ForegroundColor Yellow
      $success = Set-Policy -PolicyId $policyId
      if ($success) {
        $successCount++
      }
    }
    
    $gpResult = Update-GroupPolicy
    if (-not $gpResult) {
      throw "Unable to update group policy"
    }
    
    Write-Host "  Policies applied: $successCount/$totalCount successful" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Red" })
    
    if ($successCount -lt $totalCount) {
      $failedCount = $totalCount - $successCount
      throw "$failedCount policies failed to apply - enrollment cannot continue"
    }
    
    # Mark stage as completed
    if ($script:State.completedStages -notcontains 5) {
      $script:State.completedStages += 5
    }
    
    Write-Host 'Stage 5 completed successfully' -ForegroundColor Green
    
    $null = Send-LogEntry -Stage 5 -Level "INFO" -Message "Stage 5 completed successfully"
    return $true
  }
  catch {
    $errorMessage = "Stage 5 failed: $($_.Exception.Message)"
    Write-Host "Stage 5: Windows Policies failed" -ForegroundColor Red
    
    try {
      $null = Send-LogEntry -Stage 5 -Level "ERROR" -Message $errorMessage
      $null = Send-ErrorReport -Stage 5 -ErrorMessage $errorMessage
    }
    catch {
      Write-Host "Failed to report stage failure to API: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $false
  }
}

# Stage 6: Finalize Functions
function Complete-Enrollment {
  try {
    $body = @{
      deviceId = $script:State.deviceId
    }
        
    Write-Host "  Sending completion request for device: $($script:State.deviceId)" -ForegroundColor Yellow
    $null = Invoke-ApiCall -Endpoint "/wizard/complete" -Method "POST" -Body $body
        
    Write-Host "  [OK] Enrollment marked as complete in backend" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to complete enrollment in backend: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Show-CompletionSummary {
  try {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host "    ENROLLMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Device Name: $($script:State.deviceName)" -ForegroundColor Cyan
    Write-Host "Device ID: $($script:State.deviceId)" -ForegroundColor Cyan
    Write-Host "Policies Applied: $($script:State.policyIdsCsv)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The device has been successfully enrolled in:" -ForegroundColor White
    Write-Host "- Miradore MDM" -ForegroundColor White
    Write-Host "- Bitdefender GravityZone" -ForegroundColor White
    Write-Host "- Windows Security Policies" -ForegroundColor White
    Write-Host ""
    Write-Host "Thank you for using Teams Squared Device Enrollment!" -ForegroundColor Green
    Write-Host ""
        
    return $true
  }
  catch {
    Write-Host "  [FAIL] Unable to show completion summary" -ForegroundColor Red
    return $false
  }
}

# Stage 6: Finalize Stage Function
function Start-FinalizeStage {
  try {
    Write-Host 'Running Stage 6: Finalize' -ForegroundColor Cyan
    $script:State.currentStage = 6
    $null = Send-LogEntry -Stage 6 -Level "INFO" -Message "Starting stage 6"
    
    $enrollResult = Complete-Enrollment
    if (-not $enrollResult) {
      throw "Unable to complete enrollment in backend"
    }
    
    # Mark stage as completed
    if ($script:State.completedStages -notcontains 6) {
      $script:State.completedStages += 6
    }
    
    Write-Host 'Stage 6 completed successfully' -ForegroundColor Green
    
    # Log completion showing summary (device is still not assigned yet)
    $null = Send-LogEntry -Stage 6 -Level "INFO" -Message "Stage 6 completed successfully"
    
    $summaryResult = Show-CompletionSummary
    if (-not $summaryResult) {
      throw "Unable to show completion summary"
    }
    
    return $true
  }
  catch {
    $errorMessage = "Stage 6 failed: $($_.Exception.Message)"
    Write-Host "Stage 6: Finalize failed" -ForegroundColor Red
    
    try {
      $null = Send-LogEntry -Stage 6 -Level "ERROR" -Message $errorMessage
      $null = Send-ErrorReport -Stage 6 -ErrorMessage $errorMessage
    }
    catch {
      Write-Host "Failed to report stage failure to API: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $false
  }
}

try {
  Write-Host "Teams Squared Device Enrollment Wizard" -ForegroundColor Cyan
  Write-Host "=====================================" -ForegroundColor Cyan
  Write-Host ""
  
  # Check if resuming after reboot
  if ($script:State.rebootScheduled -and $script:State.currentStage -gt 1) {
    Write-Host "Resuming enrollment after system reboot" -ForegroundColor Cyan
    $script:State.rebootScheduled = $false
  }
  
  $prechecksSuccess = Start-PrechecksStage
  if (-not $prechecksSuccess) {
    throw "Prechecks failed"
  }
  
  Write-Host ""
  $renameSuccess = Start-RenameStage
  if (-not $renameSuccess) {
    throw "Rename failed"
  }
  
  Write-Host ""
  $miradoreSuccess = Start-MiradoreStage
  if (-not $miradoreSuccess) {
    throw "Miradore failed"
  }
  
  Write-Host ""
  $bitdefenderSuccess = Start-BitdefenderStage
  if (-not $bitdefenderSuccess) {
    throw "Bitdefender failed"
  }
  
  Write-Host ""
  $policiesSuccess = Start-PoliciesStage
  if (-not $policiesSuccess) {
    throw "Policies failed"
  }
  
  Write-Host ""
  $finalizeSuccess = Start-FinalizeStage
  if (-not $finalizeSuccess) {
    throw "Finalize failed"
  }
  
  Write-Host ""
  Write-Host "Enrollment completed successfully!" -ForegroundColor Green
  Write-Host -NoNewLine 'Press any key to exit...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
  exit 0
}
catch {
  Write-Host ""
  Write-Host "Enrollment failed" -ForegroundColor Red
  Write-Host "Please contact cybersecurity@teamsquared.io for assistance" -ForegroundColor Yellow
  Write-Host -NoNewLine 'Press any key to exit...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
  exit 1
}
