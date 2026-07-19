#!/usr/bin/env bash
# Build a distributable .dmg for the macOS release of Open Filmly.
#
# Zero external dependencies — uses the built-in `hdiutil`. Run AFTER
# `flutter build macos --release`.
#
# Usage:
#   scripts/make_dmg.sh [output.dmg]
#
# Produces (default): build/Open-Filmly.dmg
set -euo pipefail

# Resolve the Flutter app dir (this script lives in scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

APP_NAME="Open Filmly"
# PRODUCT_NAME is "Open Filmly" (title case + space); keep a fallback for older
# local builds that still produce open_filmly.app.
RELEASE_DIR="build/macos/Build/Products/Release"
if [[ -d "$RELEASE_DIR/Open Filmly.app" ]]; then
  BUILT_APP="$RELEASE_DIR/Open Filmly.app"
elif [[ -d "$RELEASE_DIR/open_filmly.app" ]]; then
  BUILT_APP="$RELEASE_DIR/open_filmly.app"
else
  BUILT_APP=""
fi
OUTPUT="${1:-build/Open-Filmly.dmg}"

if [[ -z "$BUILT_APP" || ! -d "$BUILT_APP" ]]; then
  echo "error: Open Filmly.app not found under $RELEASE_DIR." >&2
  echo "Run 'flutter build macos --release' first." >&2
  exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

# Stage the .app under its display name plus an /Applications drop target.
cp -R "$BUILT_APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT"

echo "Packaging $APP_NAME.app → $OUTPUT"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$OUTPUT" >/dev/null

echo "✓ Built $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
