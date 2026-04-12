[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

function Write-Step {
    param($Number, $Message, $Color = "Yellow")
    Write-Host ""
    Write-Host "[Step $Number] $Message" -ForegroundColor $Color
    Write-Host ("=" * 40) -ForegroundColor $Color
}

function Test-Command {
    param($Command, $Name)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host "Error: $Name not found. Please install or add to PATH." -ForegroundColor Red
        exit 1
    }
    return $cmd
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "     Hai Music Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Step 1 "Checking environment..."
Test-Command "dart" "Dart SDK"
Test-Command "flutter" "Flutter SDK"
Write-Host "Dart: $(dart --version)"
Write-Host "Flutter: $(flutter --version | Select-Object -First 1)"

Write-Step 2 "Configuring Flutter mirrors..."
[System.Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "Process")
[System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "Process")
Write-Host "PUB_HOSTED_URL: $env:PUB_HOSTED_URL"
Write-Host "FLUTTER_STORAGE_BASE_URL: $env:FLUTTER_STORAGE_BASE_URL"

Write-Step 3 "Getting dependencies..."
& dart pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to get dependencies." -ForegroundColor Red
    Write-Host "Trying with verbose output..." -ForegroundColor Yellow
    & dart pub get -v
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Still failed. Please check your network connection." -ForegroundColor Red
        exit 1
    }
}
Write-Host "Dependencies ready." -ForegroundColor Green

Write-Step 4 "Building Release APK..." "Green"
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& flutter build apk --release --no-tree-shake-icons
$stopwatch.Stop()

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Error: Build failed. Please check the error messages above." -ForegroundColor Red
    exit 1
}

$flutterApkDir = "build\app\outputs\flutter-apk"

$defaultApkPath = Join-Path $flutterApkDir "app-release.apk"
$defaultApkPath = (Resolve-Path $defaultApkPath -ErrorAction SilentlyContinue).Path

if ($defaultApkPath) {
    $localPropsPath = "android\local.properties"
    $versionName = "1.0.0"
    $versionCode = "1"

    if (Test-Path $localPropsPath) {
        $content = Get-Content $localPropsPath -Raw
        if ($content -match 'flutter\.versionName=(.+)') { $versionName = $matches[1].Trim() }
        if ($content -match 'flutter\.versionCode=(\d+)') { $versionCode = $matches[1].Trim() }
    }

    $newApkName = "hai_music_v${versionName}_${versionCode}.apk"
    $newApkPath = Join-Path $flutterApkDir $newApkName

    Remove-Item $newApkPath -Force -ErrorAction SilentlyContinue
    Copy-Item $defaultApkPath $newApkPath -Force
    Write-Host "APK renamed to: $newApkName" -ForegroundColor Green
    $finalApkPath = $newApkPath
} else {
    $finalApkPath = $defaultApkPath
}

$apkSize = "unknown"
if ($finalApkPath -and (Test-Path $finalApkPath)) {
    $apkSize = (Get-Item $finalApkPath).Length / 1MB
    $apkSize = "{0:N1} MB" -f $apkSize
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "     Build Completed Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Build time: $($stopwatch.Elapsed.ToString('mm\:ss'))" -ForegroundColor Cyan
Write-Host "APK size: $apkSize" -ForegroundColor Cyan
if ($finalApkPath) {
    Write-Host "APK path: $((Resolve-Path $finalApkPath).Path)" -ForegroundColor Cyan
}
Write-Host ""
