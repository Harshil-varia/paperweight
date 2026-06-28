#!/usr/bin/env bash
#
# Paperweight installer for people who received the app (or DMG) directly.
#
# Paperweight is distributed unsigned (no paid Apple Developer account), so
# macOS quarantines it on download and may say it is "damaged" or "from an
# unidentified developer". This script copies the app into /Applications and
# removes that quarantine flag so it launches normally.
#
# Usage:
#   ./install.sh                 # auto-find Paperweight.app next to this script,
#                                #   in the current folder, or on a mounted DMG
#   ./install.sh /path/to/Paperweight.app
set -euo pipefail

find_app() {
  if [[ "${1:-}" != "" ]]; then echo "$1"; return; fi
  local here; here="$(cd "$(dirname "$0")" && pwd)"
  for c in \
    "$here/Paperweight.app" \
    "$here/../Paperweight.app" \
    "$PWD/Paperweight.app" \
    "/Volumes/Paperweight/Paperweight.app"; do
    if [[ -d "$c" ]]; then echo "$c"; return; fi
  done
  echo ""
}

APP="$(find_app "${1:-}")"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "error: could not find Paperweight.app. Pass its path:" >&2
  echo "  ./install.sh /path/to/Paperweight.app" >&2
  exit 1
fi

echo "Found: $APP"
echo "Quitting any running Paperweight..."
osascript -e 'tell application "Paperweight" to quit' 2>/dev/null || true

DEST="/Applications/Paperweight.app"
echo "Installing to $DEST ..."
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "Clearing quarantine flag..."
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "Done. Launching..."
open -a "$DEST" || true
echo
echo "Paperweight runs in the menu bar (no Dock icon). Click its glyph to open the panel."
