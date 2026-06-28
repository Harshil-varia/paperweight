#!/usr/bin/env bash
#
# Regenerate the app icon (AppIcon.appiconset) and the menu-bar template glyph
# (MenuBarGlyph.imageset) from the vector sources in scripts/icon/.
#
# Source of truth:
#   scripts/icon/paperweight-icon.svg   -> Resources/Assets.xcassets/AppIcon.appiconset
#   scripts/icon/menubar-glyph.svg      -> Resources/Assets.xcassets/MenuBarGlyph.imageset
#
# Requires: rsvg-convert (brew install librsvg).
set -euo pipefail

cd "$(dirname "$0")/.."

ICON_SRC="scripts/icon/paperweight-icon.svg"
GLYPH_SRC="scripts/icon/menubar-glyph.svg"
ICON_SET="Resources/Assets.xcassets/AppIcon.appiconset"
GLYPH_SET="Resources/Assets.xcassets/MenuBarGlyph.imageset"

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "error: rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
fi

render() { # src px out
  rsvg-convert -w "$2" -h "$2" "$1" -o "$3"
}

echo "Rendering app icon → $ICON_SET"
mkdir -p "$ICON_SET"
render "$ICON_SRC" 16   "$ICON_SET/icon-16x16-1x.png"
render "$ICON_SRC" 32   "$ICON_SET/icon-32x32-2x.png"
render "$ICON_SRC" 32   "$ICON_SET/icon-32x32-1x.png"
render "$ICON_SRC" 64   "$ICON_SET/icon-64x64-2x.png"
render "$ICON_SRC" 128  "$ICON_SET/icon-128x128-1x.png"
render "$ICON_SRC" 256  "$ICON_SET/icon-256x256-2x.png"
render "$ICON_SRC" 256  "$ICON_SET/icon-256x256-1x.png"
render "$ICON_SRC" 512  "$ICON_SET/icon-512x512-2x.png"
render "$ICON_SRC" 512  "$ICON_SET/icon-512x512-1x.png"
render "$ICON_SRC" 1024 "$ICON_SET/icon-1024x1024-2x.png"

echo "Rendering menu-bar glyph → $GLYPH_SET"
mkdir -p "$GLYPH_SET"
render "$GLYPH_SRC" 18 "$GLYPH_SET/glyph-1x.png"
render "$GLYPH_SRC" 36 "$GLYPH_SET/glyph-2x.png"
render "$GLYPH_SRC" 54 "$GLYPH_SET/glyph-3x.png"

cat > "$GLYPH_SET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "glyph-1x.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "glyph-2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "glyph-3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "template-rendering-intent" : "template" }
}
JSON

echo "Done."
