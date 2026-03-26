#!/usr/bin/env bash
# scripts/screenshots.sh — Linux / macOS lint + screenshot script
#
# 1. flutter analyze  — must pass cleanly.
# 2. dart format      — lib/, test/, integration_test/ must already be formatted.
# 3. Screenshot gen   — runs the integration test via 'flutter drive' against an
#                       Android emulator, capturing all 15 theme × style
#                       combinations and saving PNGs into the fastlane directories.
#                       If no emulator is running, one is launched automatically
#                       from the first available AVD and shut down when done.
#                       Pre-existing emulators are left running.
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
  echo "All checks passed!"
  exit 0
fi

step "Generating screenshots (Android emulator, all 15 theme x style combos)..."
echo "    Set SKIP_SCREENSHOTS=1 to skip."

# Track whether we launched the emulator so we know whether to shut it down.
OWN_EMULATOR=false
EMU_PID=""

# ── Detect a running Android device/emulator ──────────────────────────────────
DEVICE_ID="${ANDROID_DEVICE_ID:-}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "    Detecting running Android emulator..."
  DEVICE_ID=$(
    "$FLUTTER_BIN" devices 2>/dev/null \
      | grep -i '•' \
      | grep -i 'android\|emulator' \
      | head -1 \
      | awk -F'•' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}'
  ) || true
  [[ -n "$DEVICE_ID" ]] && echo "    Found running device: $DEVICE_ID"
fi

# ── Launch an AVD if no device is running ─────────────────────────────────────
if [[ -z "$DEVICE_ID" ]]; then
  # Prefer a Pixel phone AVD that uses the lighter google_apis image (not
  # google_apis_playstore), since Play Store background services can starve
  # the rendering pipeline in headless flutter drive tests.
  # 1. google_apis (non-PlayStore) Pixel first
  AVD_NAME=$(emulator -list-avds 2>/dev/null | grep -i 'GoogleAPIs' | head -1 | tr -d '[:space:]') || true
  # 2. fall back to any Pixel-named AVD
  if [[ -z "$AVD_NAME" ]]; then
    AVD_NAME=$(emulator -list-avds 2>/dev/null | grep -i 'pixel' | head -1 | tr -d '[:space:]') || true
  fi
  # 3. last resort: first AVD in list
  if [[ -z "$AVD_NAME" ]]; then
    AVD_NAME=$(emulator -list-avds 2>/dev/null | grep -m1 '\S' | tr -d '[:space:]') || true
  fi

  if [[ -z "$AVD_NAME" ]]; then
    echo
    echo "  WARNING: No Android emulator running and no AVDs configured — skipping screenshots."
    echo "           Create an AVD in Android Studio or set ANDROID_DEVICE_ID=<id>."
    echo
    echo "Lint checks passed (screenshots skipped — no emulator or AVD)."
    exit 0
  fi

  echo "    No running emulator. Launching AVD: $AVD_NAME"
  emulator -avd "$AVD_NAME" -no-window -no-audio -no-boot-anim -no-snapshot-load -gpu host >/dev/null 2>&1 &
  EMU_PID=$!
  OWN_EMULATOR=true

  echo "    Waiting for emulator to boot (up to 120 s)..."
  DEADLINE=$((SECONDS + 120))
  while [[ $SECONDS -lt $DEADLINE ]]; do
    sleep 3
    LINE=$(adb devices 2>/dev/null | grep -P 'emulator.*\tdevice$' | head -1) || true
    if [[ -n "$LINE" ]]; then
      DEVICE_ID=$(echo "$LINE" | cut -f1)
      BOOTED=$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '[:space:]') || true
      [[ "$BOOTED" == "1" ]] && break
      DEVICE_ID=""  # still booting
    fi
  done

  if [[ -z "$DEVICE_ID" ]]; then
    echo "  WARNING: Emulator did not boot in time — skipping screenshots."
    [[ -n "$EMU_PID" ]] && kill "$EMU_PID" 2>/dev/null || true
    echo "Lint checks passed (screenshots skipped — emulator boot timed out)."
    exit 0
  fi
  echo "    Emulator ready: $DEVICE_ID"
fi

# ── Keep screen awake for the duration of the test ───────────────────────────
echo "    Keeping screen awake..."
adb -s "$DEVICE_ID" shell svc power stayon true 2>/dev/null || true
adb -s "$DEVICE_ID" shell settings put system screen_off_timeout 2147483647 2>/dev/null || true

# ── Force portrait orientation ────────────────────────────────────────────────
echo "    Forcing portrait orientation on $DEVICE_ID..."
adb -s "$DEVICE_ID" shell settings put system accelerometer_rotation 0 2>/dev/null || true
adb -s "$DEVICE_ID" shell settings put system user_rotation 0 2>/dev/null || true

# Only override display size if the emulator is currently landscape (e.g. a TV AVD).
# Applying wm size on a phone AVD that is already portrait causes severe rendering
# slowdowns (~5 min/frame) due to GPU emulation recomposition.
FORCE_PORTRAIT=false
WM_SIZE_OUT=$(adb -s "$DEVICE_ID" shell wm size 2>/dev/null) || true
if [[ "$WM_SIZE_OUT" =~ ([0-9]+)x([0-9]+) ]]; then
  DISPLAY_W="${BASH_REMATCH[1]}"
  DISPLAY_H="${BASH_REMATCH[2]}"
  if [[ "$DISPLAY_W" -gt "$DISPLAY_H" ]]; then FORCE_PORTRAIT=true; fi
fi

if [[ "$FORCE_PORTRAIT" == "true" ]]; then
  echo "    Emulator is landscape (${DISPLAY_W}x${DISPLAY_H}) — overriding to 1080x1920 portrait..."
  adb -s "$DEVICE_ID" shell wm size 1080x1920 2>/dev/null || true
  adb -s "$DEVICE_ID" shell wm density 420 2>/dev/null || true

  # The display change can briefly knock the emulator offline — wait for recovery.
  echo "    Waiting for display change to settle..."
  sleep 4
  DEADLINE=$((SECONDS + 30))
  while [[ $SECONDS -lt $DEADLINE ]]; do
    DEV_STATE=$(adb -s "$DEVICE_ID" get-state 2>/dev/null | tr -d '[:space:]') || true
    [[ "$DEV_STATE" == "device" ]] && break
    sleep 2
  done
  DEV_STATE=$(adb -s "$DEVICE_ID" get-state 2>/dev/null | tr -d '[:space:]') || true
  [[ "$DEV_STATE" == "device" ]] || fail "Emulator did not recover after display resize."
else
  echo "    Emulator is already portrait (${DISPLAY_W}x${DISPLAY_H}) — skipping wm size override."
fi

# ── Run flutter drive ─────────────────────────────────────────────────────────
# --no-enable-impeller: Impeller is Flutter's new renderer but is significantly
# slower on Android emulators (OpenGLES emulation), causing 5-min/frame times.
# Skia (legacy renderer) is much faster in emulated environments.
"$FLUTTER_BIN" drive \
  --no-enable-impeller \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d "$DEVICE_ID"
DRIVE_EXIT=$?

# ── Reset display overrides (only if we applied them) ────────────────────────
if [[ "$FORCE_PORTRAIT" == "true" ]]; then
  adb -s "$DEVICE_ID" shell wm size reset 2>/dev/null || true
  adb -s "$DEVICE_ID" shell wm density reset 2>/dev/null || true
fi

# ── Shut down the emulator only if we launched it ─────────────────────────────
if [[ "$OWN_EMULATOR" == "true" ]]; then
  echo "    Shutting down emulator $DEVICE_ID..."
  adb -s "$DEVICE_ID" emu kill 2>/dev/null || true
  echo "    Emulator stopped."
fi

[[ $DRIVE_EXIT -eq 0 ]] || fail "Screenshot flutter drive failed — see output above."

ok "Screenshots generated and saved to fastlane/ directories"

echo
echo "All checks passed!"
exit 0
