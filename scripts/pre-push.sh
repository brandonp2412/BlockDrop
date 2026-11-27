#!/usr/bin/env bash
# scripts/pre-push.sh — Linux / macOS pre-push hook
#
# 1. flutter analyze  — must pass cleanly.
# 2. dart format      — lib/, test/, integration_test/ must already be formatted.
# Installed via: scripts/install-hooks.sh

set -euo pipefail

step() { echo; echo "==> $*"; }
ok()   { echo "    OK: $*"; }
fail() { echo; echo "  FAIL: $*" >&2; exit 1; }

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ -x "$ROOT/flutter/bin/flutter" ]]; then
  FLUTTER_BIN="$ROOT/flutter/bin/flutter"
  DART_BIN="$ROOT/flutter/bin/dart"
else
  FLUTTER_BIN="flutter"
  DART_BIN="dart"
fi

step "Running flutter analyze..."
"$FLUTTER_BIN" analyze || fail "flutter analyze reported issues — fix them before pushing."
ok "Analysis passed"

step "Checking dart format..."
if ! "$DART_BIN" format --set-exit-if-changed lib/ test/ integration_test/; then
  echo "    Run 'dart format lib/ test/ integration_test/' to auto-fix."
  fail "Dart format check failed — unformatted files detected."
fi
ok "Format check passed"

echo
echo "All pre-push checks passed!"
exit 0
