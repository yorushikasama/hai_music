# Hai Music Build Script
# PowerShell script to build Flutter app with proper environment setup

# Set console encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "     Hai Music Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Configure Flutter mirrors
Write-Host "[Step 1] Configuring Flutter mirrors..." -ForegroundColor Yellow
[System.Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "Process")
[System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "Process")
Write-Host "PUB_HOSTED_URL: $env:PUB_HOSTED_URL"
Write-Host "FLUTTER_STORAGE_BASE_URL: $env:FLUTTER_STORAGE_BASE_URL"
Write-Host ""

# Step 2: Check Flutter version
Write-Host "[Step 2] Checking Flutter version..." -ForegroundColor Yellow
& flutter --version
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter command failed. Please check your Flutter installation." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

# Step 3: Get dependencies
Write-Host "[Step 3] Getting dependencies..." -ForegroundColor Yellow
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to get dependencies. Trying with verbose output..." -ForegroundColor Yellow
    & flutter pub get -v
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Still failed. Please check your network connection." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}
Write-Host ""

# Step 4: Build the app
Write-Host "[Step 4] Building the app..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Select build type:"
Write-Host "  1. Debug"
Write-Host "  2. Release"
Write-Host ""
$choice = Read-Host "Enter your choice (1 or 2)"

if ($choice -eq "2") {
    Write-Host "Building Release version..." -ForegroundColor Green
    & flutter build apk --release
} else {
    Write-Host "Building Debug version..." -ForegroundColor Green
    & flutter build apk --debug
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Build failed. Please check the error messages above." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "     Build Completed Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "APK location: build\app\outputs\flutter-apk\" -ForegroundColor Cyan
Write-Host ""
Write-Host "Troubleshooting tips:"
Write-Host "  - If you see network errors, check your internet connection"
Write-Host "  - If you see permission errors, run PowerShell as Administrator"
Write-Host "  - To clean cache: flutter pub cache repair"
Write-Host ""

Read-Host "Press Enter to exit"
