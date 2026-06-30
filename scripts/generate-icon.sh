#!/usr/bin/env bash
#
# Renders Resources/AppIcon.svg into a macOS .icns (all required sizes) plus a
# README preview PNG. Run after editing the SVG.
#
# Requires: rsvg-convert (brew install librsvg), iconutil (Xcode CLT).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$ROOT/Resources/AppIcon.svg"
ICONSET="$(mktemp -d)/AppIcon.iconset"
ICNS="$ROOT/Resources/AppIcon.icns"
PREVIEW="$ROOT/Resources/icon-preview.png"

command -v rsvg-convert >/dev/null || { echo "need rsvg-convert: brew install librsvg"; exit 1; }

mkdir -p "$ICONSET"

# (size, filename) pairs required by iconutil.
render() { rsvg-convert -w "$1" -h "$1" "$SVG" -o "$ICONSET/$2"; }
render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$ICNS"
rsvg-convert -w 512 -h 512 "$SVG" -o "$PREVIEW"

echo "==> Wrote $ICNS"
echo "==> Wrote $PREVIEW"
