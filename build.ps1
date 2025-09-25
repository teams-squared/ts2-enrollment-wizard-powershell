<#
    =====================================================================
    Teams Squared Enrollment Package Builder
    Author: Teams Squared
    Contact: cybersecurity@teamsquared.io
    =====================================================================
    Version: 1.0.0
    Last Updated: 2025-09-25
    =====================================================================
    This script creates a deployment package containing:
    - enroll-combined.ps1 (main enrollment script)
    - setupdownloader_[...].exe (Bitdefender installer)
    - miradore.ppkg (Miradore MDM package)
    - README.txt (deployment instructions)
    =====================================================================
#>

# Error Action Preference
$ErrorActionPreference = "Stop"

# Build Configuration
$BuildDir = "build"
$PackageName = "TS2-Enrollment-Package"
$PackageVersion = "1.0.1"

# Source files (relative to script location)
$SourceFiles = @{
  "enroll.ps1"                                                                                                                                                 = "src\enroll.ps1"
  "setupdownloader_[aHR0cHM6Ly9jbG91ZGFwLWVjcy5ncmF2aXR5em9uZS5iaXRkZWZlbmRlci5jb20vUGFja2FnZXMvQlNUV0lOLzAvYTVBOEdnL2luc3RhbGxlci54bWw-bGFuZz1lbi1VUw==].exe" = "src\assets\setupdownloader_[aHR0cHM6Ly9jbG91ZGFwLWVjcy5ncmF2aXR5em9uZS5iaXRkZWZlbmRlci5jb20vUGFja2FnZXMvQlNUV0lOLzAvYTVBOEdnL2luc3RhbGxlci54bWw-bGFuZz1lbi1VUw==].exe"
  "miradore.ppkg"                                                                                                                                              = "src\assets\miradore.ppkg"
  "README.md"                                                                                                                                                  = "README.md"
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildPath = Join-Path $ScriptDir $BuildDir
$PackagePath = Join-Path $BuildPath "$PackageName-v$PackageVersion"

Write-Host "Building TS2 Enrollment Package" -ForegroundColor Cyan

try {
  # Create build directory
  if (Test-Path $BuildPath) {
    Remove-Item -Path $BuildPath -Recurse -Force
  }
  $null = New-Item -ItemType Directory -Path $BuildPath -Force
  $null = New-Item -ItemType Directory -Path $PackagePath -Force

  # Copy source files
  $copiedFiles = @()
  foreach ($destFile in $SourceFiles.Keys) {
    $sourceFile = Join-Path $ScriptDir $SourceFiles[$destFile]
    $destPath = Join-Path $PackagePath $destFile
        
    if (Test-Path $sourceFile) {
      Copy-Item -Path $sourceFile -Destination $destPath -Force
      $copiedFiles += $destFile
    }
    else {
      Write-Host "  [WARN] Source file not found: $sourceFile" -ForegroundColor Yellow
    }
  }

  # Create deployment ZIP
  $zipPath = Join-Path $BuildPath "$PackageName-v$PackageVersion.zip"
  $packageFiles = Get-ChildItem -Path $PackagePath -File
  $zipFiles = $packageFiles | ForEach-Object { $_.FullName }
  Compress-Archive -Path $zipFiles -DestinationPath $zipPath -Force

  # Summary
  $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
  Write-Host "  [OK] Build complete: $PackageName-v$PackageVersion.zip ($zipSize MB)" -ForegroundColor Green
  Write-Host "   Files: $($copiedFiles.Count) | Location: $zipPath" -ForegroundColor Gray

}
catch {
  Write-Host "  [FAIL] Build failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
