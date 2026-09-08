#!/usr/bin/env bash
# scripts/install-hooks.sh — Linux / macOS hook installer
#
# Creates .git/hooks/pre-push as a symlink pointing to scripts/pre-push
# (the cross-platform shim that calls scripts/pre-push.sh on Linux/macOS).
#
# Usage:
#   bash scripts/install-hooks.sh

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
HOOK_DST="$ROOT/.git/hooks/pre-push"
HOOK_SRC="$ROOT/scripts/pre-push"

chmod +x "$HOOK_SRC"
chmod +x "$ROOT/scripts/pre-push.sh"

rm -f "$HOOK_DST"

ln -sf "../../scripts/pre-push" "$HOOK_DST"

echo "Symlink created:"
echo "  $HOOK_DST -> ../../scripts/pre-push"
echo
echo "Pre-push hook installed successfully."
echo "It will run on every 'git push'. Set SKIP_SCREENSHOTS=1 to skip screenshot generation."
