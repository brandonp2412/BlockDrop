#!/bin/sh

set -u

if [ -z "${BLOCKDROP_DEVICE_TYPE:-}" ]; then
  echo "BLOCKDROP_DEVICE_TYPE must be set" >&2
  exit 1
fi

if [ -z "${EMULATOR_PORT:-}" ]; then
  echo "EMULATOR_PORT must be set" >&2
  exit 1
fi

screenshot_dir="fastlane/metadata/android/en-US/images/$BLOCKDROP_DEVICE_TYPE"
rm -rf "$screenshot_dir"
mkdir -p "$screenshot_dir"

if [ -n "${SCREENSHOT_SCREEN_SIZE:-}" ]; then
  adb -s "emulator-$EMULATOR_PORT" shell wm size "$SCREENSHOT_SCREEN_SIZE"
  expected_dimensions=$(printf '%s' "$SCREENSHOT_SCREEN_SIZE" | sed 's/x/ x /')
fi

drive_log=$(mktemp)
drive_status=0
timeout --foreground -k 30 1200 flutter drive --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d "emulator-$EMULATOR_PORT" >"$drive_log" 2>&1 || drive_status=$?

if [ "$drive_status" -eq 124 ]; then
  echo "flutter drive timed out after 20 minutes; collecting emulator diagnostics" >&2
  adb -s "emulator-$EMULATOR_PORT" logcat -d -t 300 >&2 || true
  adb -s "emulator-$EMULATOR_PORT" shell dumpsys activity top >&2 || true
  adb -s "emulator-$EMULATOR_PORT" shell ps -A >&2 || true
fi

cat "$drive_log"

for screenshot in \
  light_classic light_modern light_bubbles light_retro \
  dark_classic dark_modern dark_bubbles dark_neon dark_retro \
  black_classic black_modern black_bubbles black_neon black_retro; do
  if [ ! -s "$screenshot_dir/$screenshot.png" ]; then
    echo "Missing generated screenshot: $screenshot.png" >&2
    [ "$drive_status" -ne 0 ] && exit "$drive_status"
    exit 1
  fi
  if [ -n "${SCREENSHOT_SCREEN_SIZE:-}" ] && ! file "$screenshot_dir/$screenshot.png" | grep -Fq " $expected_dimensions,"; then
    echo "Screenshot has unexpected dimensions: $(file "$screenshot_dir/$screenshot.png")" >&2
    exit 1
  fi
done

if [ "$drive_status" -ne 0 ]; then
  if ! grep -q "All tests passed!" "$drive_log"; then
    exit "$drive_status"
  fi
  echo "flutter drive lost the emulator during teardown after all screenshots were generated"
fi
