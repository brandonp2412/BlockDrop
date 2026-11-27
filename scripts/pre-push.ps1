#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-push git hook: Flutter lint/format checks.

.DESCRIPTION
    1. flutter analyze  — must pass cleanly.
    2. dart format      — lib/, test/, integration_test/ must already be formatted.
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


Pop-Location
Write-Host "`nAll pre-push checks passed!" -ForegroundColor Green
exit 0
