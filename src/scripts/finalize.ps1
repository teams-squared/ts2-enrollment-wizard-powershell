# Stage 6: Finalize
# Completes the enrollment process and cleans up

param(
  [psobject]$Config,
  [psobject]$State,
  [string]$ApiBase,
  [string]$JWT
)


function Complete-Enrollment {
  try {
    $body = @{
      deviceId = $State.deviceId
    }
        
    $headers = @{
      "Content-Type"  = "application/json"
      "Authorization" = "Bearer $JWT"
    }
        
    $uri = "$ApiBase/enroll/complete"
    $null = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body ($body | ConvertTo-Json) -ErrorAction Stop
        
    Write-Host "  [OK] Enrollment marked as complete in backend" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "  [FAIL] Failed to complete enrollment in backend: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "Device Name: $($State.deviceName)" -ForegroundColor Cyan
    Write-Host "Device ID: $($Config.enrollmentDeviceId)" -ForegroundColor Cyan
    Write-Host "Policies Applied: $($State.policyIdsCsv)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The device has been successfully enrolled in:" -ForegroundColor White
    Write-Host "  • Miradore MDM" -ForegroundColor White
    Write-Host "  • Bitdefender GravityZone" -ForegroundColor White
    Write-Host "  • Windows Security Policies" -ForegroundColor White
    Write-Host ""
    Write-Host "Logs are available at: $script:LogPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Thank you for using Teams Squared Device Enrollment!" -ForegroundColor Green
    Write-Host ""
        
    return $true
  }
  catch {
    Write-Host "  [FAIL] Failed to show completion summary: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

# Main execution
try {
  Write-Host "Finalizing enrollment..." -ForegroundColor Yellow
    
  # Mark enrollment as complete in the backend
  $enrollResult = Complete-Enrollment
  if (-not $enrollResult) {
    throw "Failed to complete enrollment in backend"
  }
    
  # Show completion summary
  $summaryResult = Show-CompletionSummary
  if (-not $summaryResult) {
    throw "Failed to show completion summary"
  }
    
  Write-Host "Enrollment finalization completed successfully" -ForegroundColor Green
}
catch {
  Write-Host "Enrollment finalization failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
