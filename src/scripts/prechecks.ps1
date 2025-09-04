# Stage 1: Prechecks
# Validates environment and fetches device configuration from API

param(
  [psobject]$Config,
  [psobject]$State,
  [string]$ApiBase,
  [string]$JWT
)

function Test-InternetConnection {
  try {
    # Test basic connectivity
    $ping = Test-Connection -ComputerName "1.1.1.1" -Count 1 -Quiet
    if (-not $ping) {
      throw "No internet connectivity"
    }
        
    # Test API connectivity
    $healthUri = "$ApiBase/health"
    $null = Invoke-WebRequest -Uri $healthUri -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        
    Write-Host "  [OK] Internet connection verified" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Internet connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Test-LocalAccount {
  try {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $userName = $currentUser.Name
        
    if ($userName -like "MicrosoftAccount\*" -or $userName -like "AzureAD\*") {
      throw "Current user is a Microsoft Account or Azure AD account: $userName"
    }
        
    Write-Host "  [OK] User is local account: $userName" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Local account validation failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Test-WorkplaceJoin {
  try {
    $dsregStatus = & dsregcmd /status 2>$null
        
    if ($dsregStatus -match "WorkplaceJoined\s*:\s*YES") {
      throw "Device is already workplace-joined"
    }
        
    Write-Host "  [OK] Device is not workplace-joined" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Workplace join check failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Get-DeviceConfiguration {
  try {
    $body = @{
      deviceId = $Config.enrollmentDeviceId
    }
    $headers = @{
      "Content-Type"  = "application/json"
      "Authorization" = "Bearer $JWT"
    }
     
    $uri = "$ApiBase/enroll/lookup"
    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body ($body | ConvertTo-Json) -ErrorAction Stop
        
    # Update state with device configuration
    $State.deviceName = $response.deviceName
    $State.policyIdsCsv = $response.policyIdsCsv
        
    Write-Host "  [OK] Device name fetched: $($response.deviceName)" -ForegroundColor Green
    Write-Host "  [OK] Policies configured: $($response.policyIdsCsv)" -ForegroundColor Green
        
    return $true
  }
  catch {
    $statusCode = $null
    if ($_.Exception.Response) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }
    switch ($statusCode) {
      401 { 
        Write-Host "  [FAIL] Enrollment token expired or invalid" -ForegroundColor Red
        return $false
      }
      404 { 
        Write-Host "  [FAIL] Device not found or already assigned" -ForegroundColor Red
        return $false
      }
      default { 
        Write-Host "  [FAIL] Failed to fetch device configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
      }
    }
  }
}

try {
  Write-Host "Running prechecks..." -ForegroundColor Yellow
    
  # Test internet connectivity
  $internetResult = Test-InternetConnection
  if (-not $internetResult) {
    throw "Internet connectivity test failed"
  }
    
  # Test local account
  $accountResult = Test-LocalAccount
  if (-not $accountResult) {
    throw "Local account validation failed"
  }
    
  # Test workplace join status
  $workplaceResult = Test-WorkplaceJoin
  if (-not $workplaceResult) {
    throw "Workplace join check failed"
  }
    
  # Get device configuration from API
  $configResult = Get-DeviceConfiguration
  if (-not $configResult) {
    throw "Device configuration retrieval failed"
  }
    
  Write-Host "Prechecks completed successfully" -ForegroundColor Green
}
catch {
  Write-Host "Prechecks failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
