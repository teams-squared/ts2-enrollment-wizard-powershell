# Stage 4: Bitdefender GravityZone Installation
# Installs the Bitdefender Endpoint Security

param(
  [psobject]$Config,
  [psobject]$State
)

function Install-BitdefenderAgent {
  try {
    $exePath = "C:\ProgramData\TS2\Wizard\assets\epskit_x64.exe"
        
    if (-not (Test-Path $exePath)) {
      Write-Host "  [FAIL] Bitdefender agent not found at: $exePath" -ForegroundColor Red
      return $false
    }
        
    Write-Host "  Installing Bitdefender GravityZone agent..." -ForegroundColor Yellow
        
    # Install Bitdefender in a separate window (non-blocking)
    $process = Start-Process -FilePath $exePath -ArgumentList "/quiet /norestart" -PassThru
        
    Write-Host "  Bitdefender installation started in separate window (PID: $($process.Id))" -ForegroundColor Cyan
    Write-Host "  Waiting for installation to complete..." -ForegroundColor Yellow
        
    # Wait for the process to complete
    $process.WaitForExit()
        
    if ($process.ExitCode -ne 0) {
      Write-Host "  [FAIL] Bitdefender agent installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
      return $false
    }
        
    Write-Host "  [OK] Bitdefender agent completed successfully" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Bitdefender agent installation failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Test-BitdefenderService {
  try {
    $serviceName = "EPSecurityService"

    # Wait for the service to be created and started
    Write-Host "  Waiting for Bitdefender agent service to start..." -ForegroundColor Yellow
    $null = Start-Sleep -Seconds 30
        
    # Check if the Bitdefender service exists and is running
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        
    if (-not $service) {
      Write-Host "  [FAIL] Bitdefender agent service not found" -ForegroundColor Red
      return $false
    }
        
    # Wait for service to start (it may take some time)
    $timeout = 120 # 2 minutes
    $elapsed = 0
        
    while ($service.Status -ne "Running" -and $elapsed -lt $timeout) {
      $null = Start-Sleep -Seconds 5
      $elapsed += 5
      $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
      Write-Host "  Waiting for service to start... ($elapsed/$timeout seconds)" -ForegroundColor Yellow
    }
        
    if ($service.Status -ne "Running") {
      Write-Host "  [FAIL] Bitdefender agent service failed to start within timeout period" -ForegroundColor Red
      return $false
    }
        
    Write-Host "  [OK] Bitdefender agent service is running" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Bitdefender agent service verification failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Test-BitdefenderInstallation {
  try {
    # Check if Bitdefender is properly installed by looking for the installation directory
    $installPath = "${env:ProgramFiles}\Bitdefender\Endpoint Security"
    if (-not (Test-Path $installPath)) {
      $installPath = "${env:ProgramFiles(x86)}\Bitdefender\Endpoint Security"
    }
        
    if (-not (Test-Path $installPath)) {
      Write-Host "  [FAIL] Bitdefender installation directory not found" -ForegroundColor Red
      return $false
    }
        
    Write-Host "  [OK] Bitdefender installation verified" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Bitdefender installation verification failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

# Main execution
try {
  Write-Host "Installing Bitdefender GravityZone..." -ForegroundColor Yellow
    
  # Install Bitdefender agent
  $installResult = Install-BitdefenderAgent
  if (-not $installResult) {
    throw "Bitdefender agent installation failed"
  }
    
  # Verify service is running
  $serviceResult = Test-BitdefenderService
  if (-not $serviceResult) {
    throw "Bitdefender service verification failed"
  }
    
  # Verify installation
  $verifyResult = Test-BitdefenderInstallation
  if (-not $verifyResult) {
    throw "Bitdefender installation verification failed"
  }
    
  Write-Host "Bitdefender GravityZone installation completed successfully" -ForegroundColor Green
}
catch {
  Write-Host "Bitdefender GravityZone installation failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
