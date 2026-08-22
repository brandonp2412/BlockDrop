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
fi

cat "$drive_log"

screenshot_count=$(find "$screenshot_dir" -type f -name '*.png' | wc -l)
if [ "$screenshot_count" -ne 14 ]; then
  echo "Expected 14 screenshots, found $screenshot_count" >&2
  [ "$drive_status" -ne 0 ] && exit "$drive_status"
  exit 1
fi

if [ "$drive_status" -ne 0 ]; then
  if ! grep -q "All tests passed!" "$drive_log"; then
    exit "$drive_status"
  fi
  echo "flutter drive lost the emulator during teardown after screenshots were generated"
fi
