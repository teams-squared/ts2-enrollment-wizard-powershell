# Stage 2: Rename Computer
# Renames the computer and sets up scheduled task for resume after reboot

param(
  [psobject]$Config,
  [psobject]$State
)

function Set-ComputerName {
  try {
    $currentName = $env:COMPUTERNAME
    $newName = $State.deviceName
        
    Write-Host "  Renaming computer from '$currentName' to '$newName'..." -ForegroundColor Yellow
        
    # Rename the computer
    Rename-Computer -NewName $newName -Force -ErrorAction Stop
        
    Write-Host "  [OK] Computer renamed successfully" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Failed to rename computer: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function New-ResumeTask {
  try {
    $taskName = "TS2-Resume"
    $taskPath = "C:\ProgramData\TS2\Wizard\enroll.ps1"
        
    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
      Write-Host "  [OK] Resume task already exists" -ForegroundColor Green
      return $true
    }
        
    # Create the scheduled task action with explicit path
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$taskPath`""
        
    # Create the scheduled task trigger (at logon - works for both startup and restart)
    $trigger = New-ScheduledTaskTrigger -AtLogOn
        
    # Register the scheduled task
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description "Teams Squared Enrollment Resume Task" -Force
        
    Write-Host "  [OK] Resume task created successfully" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Failed to create resume task: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Remove-ResumeTask {
  try {
    $taskName = "TS2-Resume"
        
    # Check if task exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
      Write-Host "  [OK] Resume task removed" -ForegroundColor Green
    }
    else {
      Write-Host "  [OK] Resume task not found (already removed)" -ForegroundColor Green
    }
        
    return $true
  }
  catch {
    Write-Host "  [FAIL] Failed to remove resume task: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Start-SystemReboot {
  try {
    Write-Host "  Scheduling system reboot in 10 seconds..." -ForegroundColor Yellow
    Write-Host "  The system will automatically resume enrollment after reboot." -ForegroundColor Cyan
        
    # Schedule reboot
    shutdown /r /t 10 /c "Teams Squared Enrollment: Rebooting to apply computer name change"
        
    Write-Host "  [OK] Reboot scheduled" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Failed to schedule reboot: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

try {
  Write-Host "Renaming computer..." -ForegroundColor Yellow

  # Exit gracefully if the computer is already renamed
  if ($State.deviceName -eq $env:COMPUTERNAME) {
    Write-Host "  Computer is already renamed to '$($State.deviceName)'" -ForegroundColor Green
    
    # Remove the resume task since we don't need it anymore
    $removeResult = Remove-ResumeTask
    if (-not $removeResult) {
      throw "Failed to remove resume task"
    }
    
    exit 0
  }
    
  # Rename the computer
  $renameResult = Set-ComputerName
  if (-not $renameResult) {
    throw "Computer rename failed"
  }
    
  # Create resume task
  $taskResult = New-ResumeTask
  if (-not $taskResult) {
    throw "Resume task creation failed"
  }
    
  # Schedule reboot
  $rebootResult = Start-SystemReboot
  if (-not $rebootResult) {
    throw "System reboot scheduling failed"
  }
    
  Write-Host "Computer rename completed successfully" -ForegroundColor Green
  
  # Mark that a reboot is scheduled in the state
  $State.rebootScheduled = $true
  
  # Exit gracefully - the scheduled task will resume enrollment after reboot
  exit 0
}
catch {
  Write-Host "Computer rename failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
