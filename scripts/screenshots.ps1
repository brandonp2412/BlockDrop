#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Flutter lint/format checks and screenshot generation for Block Drop.

.DESCRIPTION
    1. flutter analyze  — must pass cleanly.
    2. dart format      — lib/, test/, integration_test/ must already be formatted.
    3. Screenshot gen   — runs the integration test via 'flutter drive' against an
                          Android emulator, capturing all 15 theme × style
                          combinations and saving PNGs into the fastlane directory
                          structure.  If no emulator is running, one is launched
                          automatically from the first available AVD and shut down
                          when done.  Pre-existing emulators are left running.

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
    Write-Host "`nAll checks passed!" -ForegroundColor Green
    exit 0
}

Write-Step "Generating screenshots (Android emulator, all 15 theme x style combos)..."
Write-Host "    Set SKIP_SCREENSHOTS=1 to skip." -ForegroundColor DarkGray

# Track whether we launched the emulator so we know whether to shut it down.
$ownEmulator = $false
$emuProc = $null

# ── Detect a running Android device/emulator ──────────────────────────────────
$deviceId = $env:ANDROID_DEVICE_ID
if (-not $deviceId) {
    Write-Host "    Detecting running Android emulator..." -ForegroundColor Yellow
    $devicesOutput = & $FLUTTER_BIN devices 2>&1

    $emulatorLine = $devicesOutput |
        Where-Object { $_ -match 'android' } |
        Select-Object -First 1

    if ($emulatorLine) {
        if ($emulatorLine -match '(?<=\s)\S+\s+•\s+(\S+)\s+•') {
            $deviceId = $Matches[1]
        } elseif ($emulatorLine -match '(emulator-\d+)') {
            $deviceId = $Matches[1]
        }
        if ($deviceId) {
            Write-Host "    Found running device: $deviceId" -ForegroundColor Yellow
        }
    }
}

# ── Launch an AVD if no device is running ─────────────────────────────────────
if (-not $deviceId) {
    $avds = & emulator -list-avds 2>$null | Where-Object { $_ -match '\S' }
    # Prefer a Pixel phone AVD that uses the lighter google_apis image (not
    # google_apis_playstore), since Play Store background services can starve
    # the rendering pipeline in headless flutter drive tests.
    $avdName = if ($avds) {
        # google_apis (non-PlayStore) Pixel first
        $phone = $avds | Where-Object { $_ -imatch 'GoogleAPIs' } | Select-Object -First 1
        # fall back to any Pixel-named AVD
        if (-not $phone) { $phone = $avds | Where-Object { $_ -imatch 'pixel' } | Select-Object -First 1 }
        # last resort: first AVD in list
        if ($phone) { $phone.Trim() } else { ($avds | Select-Object -First 1).Trim() }
    } else { $null }

    if (-not $avdName) {
        Write-Host "`n  WARNING: No Android emulator running and no AVDs configured — skipping screenshots." -ForegroundColor Yellow
        Write-Host "           Create an AVD in Android Studio or set ANDROID_DEVICE_ID=<id>." -ForegroundColor Yellow
        Pop-Location
        Write-Host "`nLint checks passed (screenshots skipped — no emulator or AVD)." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "    No running emulator. Launching AVD: $avdName" -ForegroundColor Yellow
    $emuProc = Start-Process -FilePath "emulator" `
        -ArgumentList @("-avd", $avdName, "-no-window", "-no-audio", "-no-boot-anim", "-no-snapshot-load", "-gpu", "host") `
        -PassThru -WindowStyle Hidden
    $ownEmulator = $true

    Write-Host "    Waiting for emulator to boot (up to 120 s)..." -ForegroundColor Yellow
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $line = & adb devices 2>$null |
            Where-Object { $_ -match 'emulator' -and $_ -match "`tdevice$" } |
            Select-Object -First 1
        if ($line) {
            $deviceId = ($line -split "`t")[0].Trim()
            $booted = ((& adb -s $deviceId shell getprop sys.boot_completed 2>$null) -join '').Trim()
            if ($booted -eq '1') { break }
            $deviceId = $null  # still booting
        }
    }

    if (-not $deviceId) {
        Write-Host "  WARNING: Emulator did not boot in time — skipping screenshots." -ForegroundColor Yellow
        if ($emuProc -and -not $emuProc.HasExited) { $emuProc.Kill() }
        Pop-Location
        Write-Host "`nLint checks passed (screenshots skipped — emulator boot timed out)." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "    Emulator ready: $deviceId" -ForegroundColor Yellow
}

# ── Keep screen awake for the duration of the test ───────────────────────────
Write-Host "    Keeping screen awake..." -ForegroundColor Yellow
& adb -s $deviceId shell svc power stayon true 2>$null
& adb -s $deviceId shell settings put system screen_off_timeout 2147483647 2>$null

# ── Force portrait orientation ────────────────────────────────────────────────
Write-Host "    Forcing portrait orientation on $deviceId..." -ForegroundColor Yellow
& adb -s $deviceId shell settings put system accelerometer_rotation 0 2>$null
& adb -s $deviceId shell settings put system user_rotation 0 2>$null

# Only override display size if the emulator is currently landscape (e.g. a TV AVD).
# Applying wm size on a phone AVD that is already portrait causes severe rendering
# slowdowns (~5 min/frame) due to GPU emulation recomposition.
$wmSizeOutput = (& adb -s $deviceId shell wm size 2>$null) -join ''
$forcePortrait = $false
if ($wmSizeOutput -match '(\d+)x(\d+)') {
    $displayW = [int]$Matches[1]
    $displayH = [int]$Matches[2]
    if ($displayW -gt $displayH) { $forcePortrait = $true }
}

if ($forcePortrait) {
    Write-Host "    Emulator is landscape ($displayW x$displayH) — overriding to 1080x1920 portrait..." -ForegroundColor Yellow
    & adb -s $deviceId shell wm size 1080x1920 2>$null
    & adb -s $deviceId shell wm density 420 2>$null

    # The display change can briefly knock the emulator offline — wait for it to recover.
    Write-Host "    Waiting for display change to settle..." -ForegroundColor Yellow
    Start-Sleep -Seconds 4
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        $devState = (& adb -s $deviceId get-state 2>$null).Trim()
        if ($devState -eq 'device') { break }
        Start-Sleep -Seconds 2
    }
    $devState = (& adb -s $deviceId get-state 2>$null).Trim()
    if ($devState -ne 'device') { Fail "Emulator did not recover after display resize." }
} else {
    Write-Host "    Emulator is already portrait ($displayW x$displayH) — skipping wm size override." -ForegroundColor Green
}

# ── Run flutter drive ─────────────────────────────────────────────────────────
# --no-enable-impeller: Impeller is Flutter's new renderer but is significantly
# slower on Android emulators (OpenGLES emulation), causing 5-min/frame times.
# Skia (legacy renderer) is much faster in emulated environments.
& $FLUTTER_BIN drive `
    --no-enable-impeller `
    --driver=test_driver/integration_test.dart `
    --target=integration_test/screenshot_test.dart `
    -d $deviceId
$driveExitCode = $LASTEXITCODE

# ── Reset display overrides (only if we applied them) ────────────────────────
if ($forcePortrait) {
    & adb -s $deviceId shell wm size reset 2>$null
    & adb -s $deviceId shell wm density reset 2>$null
}

# ── Shut down the emulator only if we launched it ─────────────────────────────
if ($ownEmulator) {
    Write-Host "    Shutting down emulator $deviceId..." -ForegroundColor Yellow
    & adb -s $deviceId emu kill 2>$null
    Write-Host "    Emulator stopped." -ForegroundColor Yellow
}

if ($driveExitCode -ne 0) {
    Fail "Screenshot flutter drive failed — see output above."
}
Write-OK "Screenshots generated and saved to fastlane/ directories"

Pop-Location
Write-Host "`nAll checks passed!" -ForegroundColor Green
exit 0
