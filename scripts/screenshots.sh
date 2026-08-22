#!/bin/bash
# Generate Block Drop screenshots on an existing Android device.

set -e

device="${1:?Usage: screenshots.sh <device-id> [device-type] [screenshot]}"
device_type="${2:-phoneScreenshots}"
only="${3:-}"

export BLOCKDROP_DEVICE_TYPE="$device_type"

dart_define=()
if [ -n "$only" ]; then
  dart_define=(--dart-define=SCREENSHOT_ONLY="$only")
  echo "Capturing only: $only"
fi

flutter drive --profile --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  "${dart_define[@]}" \
  -d "$device"
