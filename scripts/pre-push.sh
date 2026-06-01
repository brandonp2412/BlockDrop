#!/usr/bin/env bash
# scripts/pre-push.sh — Linux / macOS pre-push hook
#
# 1. flutter analyze  — must pass cleanly.
# 2. dart format      — lib/, test/, integration_test/ must already be formatted.
# 3. Screenshot gen   — runs the integration test via 'flutter drive' against a
#                       connected Android emulator, capturing all 15 theme × style
#                       combinations and saving PNGs into the fastlane directories.
#
# Environment variables:
#   SKIP_SCREENSHOTS=1      Skip step 3 (lint checks still run).
#   ANDROID_DEVICE_ID=<id>  Target a specific Android device/emulator.
#
# Installed via: scripts/install-hooks.sh

set -euo pipefail

step() { echo; echo "==> $*"; }
ok()   { echo "    OK: $*"; }
fail() { echo; echo "  FAIL: $*" >&2; exit 1; }

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Use the project's own Flutter submodule if present, otherwise fall back to PATH.
if [[ -x "$ROOT/flutter/bin/flutter" ]]; then
  FLUTTER_BIN="$ROOT/flutter/bin/flutter"
  DART_BIN="$ROOT/flutter/bin/dart"
else
  FLUTTER_BIN="flutter"
  DART_BIN="dart"
fi

# ── 1. Flutter analyze ────────────────────────────────────────────────────────
step "Running flutter analyze..."
"$FLUTTER_BIN" analyze || fail "flutter analyze reported issues — fix them before pushing."
ok "Analysis passed"

# ── 2. Dart format ────────────────────────────────────────────────────────────
step "Checking dart format..."
if ! "$DART_BIN" format --set-exit-if-changed lib/ test/ integration_test/; then
  echo "    Run 'dart format lib/ test/ integration_test/' to auto-fix."
  fail "Dart format check failed — unformatted files detected."
fi
ok "Format check passed"

# ── 3. Screenshots via Android emulator ───────────────────────────────────────
if [[ "${SKIP_SCREENSHOTS:-0}" == "1" ]]; then
  echo
  echo "  Skipping screenshots (SKIP_SCREENSHOTS=1)"
  echo
  echo "All pre-push checks passed!"
  exit 0
fi

step "Generating screenshots (Android emulator, all 15 theme x style combos)..."
echo "    Set SKIP_SCREENSHOTS=1 to skip."

# Determine target device
DEVICE_ID="${ANDROID_DEVICE_ID:-}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "    Detecting running Android emulator..."
  # flutter devices format: "<name> • <id> • <platform> • <details>"
  # Extract the device ID (second bullet-delimited field) from Android lines.
  DEVICE_ID=$(
    "$FLUTTER_BIN" devices 2>/dev/null \
      | grep -i '•' \
      | grep -i 'android\|emulator' \
      | head -1 \
      | awk -F'•' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}'
  ) || true
  [[ -n "$DEVICE_ID" ]] && echo "    Found device: $DEVICE_ID"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo
  echo "  WARNING: No Android emulator found — skipping screenshots."
  echo "           Start an AVD and set ANDROID_DEVICE_ID=<id> to enable."
  echo
  echo "Lint checks passed (screenshots skipped — no emulator)."
  exit 0
fi

"$FLUTTER_BIN" drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d "$DEVICE_ID"
DRIVE_EXIT=$?

# Shut down the emulator now that we're done with it.
echo "    Shutting down emulator $DEVICE_ID..."
adb -s "$DEVICE_ID" emu kill 2>/dev/null || true
echo "    Emulator stopped."

[[ $DRIVE_EXIT -eq 0 ]] || fail "Screenshot flutter drive failed — see output above."

ok "Screenshots generated and saved to fastlane/ directories"

echo
echo "All pre-push checks passed!"
exit 0
