#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-push git hook: Flutter lint/format checks and screenshot generation.

.DESCRIPTION
    1. flutter analyze  — must pass cleanly.
    2. dart format      — lib/, test/, integration_test/ must already be formatted.
    3. Screenshot gen   — runs the integration test via 'flutter drive' against a
                          connected Android emulator, capturing all 15 theme × style
                          combinations and saving PNGs into the fastlane directory
                          structure.

    Set SKIP_SCREENSHOTS=1 to skip step 3 (lint checks still run).
    Set ANDROID_DEVICE_ID=<id> to target a specific Android device/emulator.

.NOTES
    Installed via: scripts/install-hooks.ps1
    The hook shim at .git/hooks/pre-push is symlinked to scripts/pre-push.
#>

$ErrorActionPreference = "Stop"

# ── helpers ──────────────────────────────────────────────────────────────────
function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK([string]$msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Fail([string]$msg) {
    Write-Host "`n  FAIL: $msg" -ForegroundColor Red
    exit 1
}

$ROOT = (& git rev-parse --show-toplevel) -replace '/', '\'
Push-Location $ROOT

# Use the project's own Flutter submodule if present, otherwise fall back to PATH.
$FLUTTER_BIN = if (Test-Path "$ROOT\flutter\bin\flutter.bat") {
    "$ROOT\flutter\bin\flutter.bat"
} else {
    "flutter"
}
$DART_BIN = if (Test-Path "$ROOT\flutter\bin\dart.bat") {
    "$ROOT\flutter\bin\dart.bat"
} else {
    "dart"
}

# ── 1. Flutter analyze ────────────────────────────────────────────────────────
Write-Step "Running flutter analyze..."
& $FLUTTER_BIN analyze
if ($LASTEXITCODE -ne 0) { Fail "flutter analyze reported issues — fix them before pushing." }
Write-OK "Analysis passed"

# ── 2. Dart format ────────────────────────────────────────────────────────────
Write-Step "Checking dart format..."
& $DART_BIN format --set-exit-if-changed lib/ test/ integration_test/
if ($LASTEXITCODE -ne 0) {
    Write-Host "    Run 'dart format lib/ test/ integration_test/' to auto-fix." -ForegroundColor Yellow
    Fail "Dart format check failed — unformatted files detected."
}
Write-OK "Format check passed"

# ── 3. Screenshots via Android emulator ───────────────────────────────────────
if ($env:SKIP_SCREENSHOTS -eq "1") {
    Write-Host "`n  Skipping screenshots (SKIP_SCREENSHOTS=1)" -ForegroundColor Yellow
    Pop-Location
    Write-Host "`nAll pre-push checks passed!" -ForegroundColor Green
    exit 0
}

Write-Step "Generating screenshots (Android emulator, all 15 theme x style combos)..."
Write-Host "    Set SKIP_SCREENSHOTS=1 to skip." -ForegroundColor DarkGray

# Determine target device
$deviceId = $env:ANDROID_DEVICE_ID
if (-not $deviceId) {
    Write-Host "    Detecting running Android emulator..." -ForegroundColor Yellow
    $devicesOutput = & $FLUTTER_BIN devices 2>&1

    # flutter devices format: "<name> • <id> • <platform> • <details>"
    # Match lines that mention 'android' (covers android-x64, android-arm, etc.)
    $emulatorLine = $devicesOutput |
        Where-Object { $_ -match 'android' } |
        Select-Object -First 1

    if ($emulatorLine) {
        # Try to extract emulator-NNNN or any device id from the line.
        # The device id is the segment between the first and second bullet characters.
        if ($emulatorLine -match '(?<=\s)\S+\s+•\s+(\S+)\s+•') {
            $deviceId = $Matches[1]
        } else {
            # Fallback: grab 'emulator-NNNN' directly
            if ($emulatorLine -match '(emulator-\d+)') {
                $deviceId = $Matches[1]
            }
        }
        if ($deviceId) {
            Write-Host "    Found device: $deviceId" -ForegroundColor Yellow
        }
    }
}

if (-not $deviceId) {
    Write-Host "`n  WARNING: No Android emulator found — skipping screenshots." -ForegroundColor Yellow
    Write-Host "           Start an AVD and set ANDROID_DEVICE_ID=<id> to enable." -ForegroundColor Yellow
    Pop-Location
    Write-Host "`nLint checks passed (screenshots skipped — no emulator)." -ForegroundColor Yellow
    exit 0
}

& $FLUTTER_BIN drive `
    --driver=test_driver/integration_test.dart `
    --target=integration_test/screenshot_test.dart `
    -d $deviceId
$driveExitCode = $LASTEXITCODE

# Shut down the emulator now that we're done with it.
Write-Host "    Shutting down emulator $deviceId..." -ForegroundColor Yellow
& adb -s $deviceId emu kill 2>$null
Write-Host "    Emulator stopped." -ForegroundColor Yellow

if ($driveExitCode -ne 0) {
    Fail "Screenshot flutter drive failed — see output above."
}
Write-OK "Screenshots generated and saved to fastlane/ directories"

Pop-Location
Write-Host "`nAll pre-push checks passed!" -ForegroundColor Green
exit 0
