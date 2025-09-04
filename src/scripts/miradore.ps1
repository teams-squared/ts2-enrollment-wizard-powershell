# Stage 3: Miradore MDM Installation
# Installs the Miradore Online Client

param(
  [psobject]$Config,
  [psobject]$State
)

function Install-MiradoreClient {
  try {
    $msiPath = "C:\ProgramData\TS2\Wizard\assets\mdm.msi"
    if (-not (Test-Path $msiPath)) {
      throw "Miradore MSI not found at: $msiPath"
    }
        
    Write-Host "  Installing Miradore client..." -ForegroundColor Yellow
        
    # Install the MSI in a separate window (non-blocking)
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn /norestart" -PassThru
        
    Write-Host "  Miradore installation started in separate window (PID: $($process.Id))" -ForegroundColor Cyan
    Write-Host "  Waiting for installation to complete..." -ForegroundColor Yellow
        
    # Wait for the process to complete
    $process.WaitForExit()
        
    if ($process.ExitCode -ne 0) {
      throw "Miradore client installation failed with exit code: $($process.ExitCode)"
    }
        
    Write-Host "  [OK] Miradore client installed successfully" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Miradore client installation failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Test-MiradoreService {
  try {
    $serviceName = "miradoreclient"

    # Wait for the service to be created and started
    $null = Start-Sleep -Seconds 20
        
    # Check if the Miradore service exists and is running
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        
    if (-not $service) {
      throw "Miradore client service not found"
    }
        
    if ($service.Status -ne "Running") {
      Write-Host "  Starting Miradore client service..." -ForegroundColor Yellow
      $null = Start-Service -Name $serviceName -ErrorAction Stop
    }
        
    Write-Host "  [OK] Miradore client service is running" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Miradore client service verification failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Test-MiradoreInstallation {
  try {
    # Check if Miradore is properly installed by looking for the installation directory
    $installPath = "${env:ProgramFiles(x86)}\Miradore\OnlineClient"
    if (-not (Test-Path $installPath)) {
      $installPath = "${env:ProgramFiles}\Miradore\OnlineClient"
    }
        
    if (-not (Test-Path $installPath)) {
      throw "Miradore installation directory not found"
    }
        
    Write-Host "  [OK] Miradore installation verified" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Miradore installation verification failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

# Main execution
try {
  Write-Host "Installing Miradore MDM..." -ForegroundColor Yellow
    
  # Install Miradore client
  $installResult = Install-MiradoreClient
  if (-not $installResult) {
    throw "Miradore client installation failed"
  }
    
  # Verify service is running
  $serviceResult = Test-MiradoreService
  if (-not $serviceResult) {
    throw "Miradore service verification failed"
  }
    
  # Verify installation
  $verifyResult = Test-MiradoreInstallation
  if (-not $verifyResult) {
    throw "Miradore installation verification failed"
  }
    
  Write-Host "Miradore MDM installation completed successfully" -ForegroundColor Green
}
catch {
  Write-Host "Miradore MDM installation failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
