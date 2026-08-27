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

device="emulator-$EMULATOR_PORT"
screenshot_dir="fastlane/metadata/android/en-US/images/$BLOCKDROP_DEVICE_TYPE"

wait_for_emulator() {
  timeout 60 adb -s "$device" wait-for-device >/dev/null 2>&1 || return 1

  checks=0
  while [ "$checks" -lt 30 ]; do
    state=$(adb -s "$device" get-state 2>/dev/null || true)
    boot_completed=$(adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
    if [ "$state" = "device" ] && [ "$boot_completed" = "1" ]; then
      return 0
    fi
    sleep 2
    checks=$((checks + 1))
  done

  return 1
}

recover_emulator() {
  echo "Recovering emulator transport before retry" >&2
  adb kill-server >/dev/null 2>&1 || true
  adb start-server >/dev/null 2>&1 || true
  adb reconnect offline >/dev/null 2>&1 || true
  wait_for_emulator
}

collect_diagnostics() {
  adb -s "$device" logcat -d -t 300 >&2 || true
  adb -s "$device" shell dumpsys activity top >&2 || true
  adb -s "$device" shell ps -A >&2 || true
}

if ! wait_for_emulator; then
  recover_emulator || {
    echo "Emulator did not become ready" >&2
    collect_diagnostics
    exit 1
  }
fi

if [ -n "${SCREENSHOT_SCREEN_SIZE:-}" ]; then
  adb -s "$device" shell wm size "$SCREENSHOT_SCREEN_SIZE"
  expected_dimensions=$(printf '%s' "$SCREENSHOT_SCREEN_SIZE" | sed 's/x/ x /')
fi

drive_log=$(mktemp)
drive_status=0
attempt=1

while :; do
  rm -rf "$screenshot_dir"
  mkdir -p "$screenshot_dir"
  drive_status=0

  timeout --foreground -k 30 570 flutter drive --profile \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshot_test.dart \
    -d "$device" >"$drive_log" 2>&1 || drive_status=$?

  cat "$drive_log"

  if [ "$drive_status" -eq 0 ] || grep -q "All tests passed!" "$drive_log"; then
    break
  fi

  transient_failure=0
  if [ "$drive_status" -eq 124 ] || grep -Eiq \
    'device offline|Connection reset|VMServiceFlutterDriver: It is taking an unusually long time to connect' \
    "$drive_log"; then
    transient_failure=1
  fi

  if [ "$transient_failure" -ne 1 ] || [ "$attempt" -ge 2 ]; then
    collect_diagnostics
    break
  fi

  echo "Transient emulator failure on screenshot attempt $attempt; retrying once" >&2
  collect_diagnostics
  recover_emulator || break
  attempt=$((attempt + 1))
  drive_log=$(mktemp)
done

for screenshot in \
  1_en-US 2_en-US 3_en-US 4_en-US 5_en-US 6_en-US 7_en-US \
  8_en-US 9_en-US 10_en-US 11_en-US 12_en-US 13_en-US 14_en-US; do
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
