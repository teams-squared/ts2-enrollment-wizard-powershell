# Stage 5: Windows Policies
# Applies Windows security policies based on the policy IDs

param(
  [psobject]$Config,
  [psobject]$State
)

function Get-PolicyIds {
  try {
    if (-not $State.policyIdsCsv) {
      Write-Host "  No policies to apply" -ForegroundColor Yellow
      return @()
    }
        
    $policyIds = $State.policyIdsCsv.Split(',') | ForEach-Object { [int]$_.Trim() }
    Write-Host "  Applying policies: $($policyIds -join ', ')" -ForegroundColor Yellow
    return $policyIds
  }
  catch {
    Write-Host "  [FAIL] Failed to parse policy IDs: $($_.Exception.Message)" -ForegroundColor Red
    return @()
  }
}

function Set-USBReadOnlyPolicy {
  try {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
    $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "Deny_Write" -Value 1 -Type DWord -Force
    Write-Host "    [OK] USB storage: Read-only policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] USB storage: Read-only policy failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "    [FAIL] USB storage: Block all policy failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Set-MTPWPDPolicy {
  try {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PortableOperatingSystem"
    $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "AllowMTP" -Value 0 -Type DWord -Force
        
    # Block Windows Portable Devices
    $wpdPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PortableDevices"
    $null = New-Item -Path $wpdPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $wpdPath -Name "DenyAll" -Value 1 -Type DWord -Force
        
    Write-Host "    [OK] Block MTP/WPD policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] Block MTP/WPD policy failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Set-AutoLockPolicy {
  try {
    # Set screen saver timeout to 10 minutes (600 seconds)
    $regPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -Value "600" -Force
        
    # Enable screen saver
    Set-ItemProperty -Path $regPath -Name "ScreenSaveActive" -Value "1" -Force
        
    # Set lock screen timeout
    $powerPath = "HKCU:\Control Panel\PowerCfg"
    $null = New-Item -Path $powerPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $powerPath -Name "CurrentPowerPolicy" -Value "0" -Force
        
    Write-Host "    [OK] Auto-lock after 10 minutes policy applied" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "    [FAIL] Auto-lock policy failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "    [FAIL] Hide last user policy failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "    [FAIL] Firewall policy failed: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "    [FAIL] Auto-update policy failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
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
    Write-Host "  Updating group policy..." -ForegroundColor Yellow
    gpupdate /force | Out-Null
    Write-Host "  [OK] Group policy updated" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Group policy update failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

# Main execution
try {
  Write-Host "Applying Windows policies..." -ForegroundColor Yellow
    
  $policyIds = Get-PolicyIds
  
  # Check if policy parsing failed (empty array when it should have policies)
  if ($State.policyIdsCsv -and $policyIds.Count -eq 0) {
    throw "Policy ID parsing failed - no valid policies found"
  }
  
  $successCount = 0
  $totalCount = $policyIds.Count
    
  if ($totalCount -eq 0) {
    Write-Host "No policies to apply" -ForegroundColor Yellow
    return
  }
    
  foreach ($policyId in $policyIds) {
    Write-Host "  Applying policy $policyId..." -ForegroundColor Yellow
    $success = Set-Policy -PolicyId $policyId
    if ($success) {
      $successCount++
    }
  }
    
  # Update group policy
  $gpResult = Update-GroupPolicy
  if (-not $gpResult) {
    throw "Group policy update failed"
  }
    
  Write-Host "Policies applied: $successCount/$totalCount successful" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Red" })
    
  if ($successCount -lt $totalCount) {
    $failedCount = $totalCount - $successCount
    throw "$failedCount policies failed to apply - enrollment cannot continue"
  }
    
  Write-Host "Windows policies stage completed" -ForegroundColor Green
}
catch {
  Write-Host "Windows policies failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
