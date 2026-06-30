#!/usr/bin/env bash
#
# Builds Multi-Month Mini Calendar as a distributable macOS .app bundle.
#
# Usage:  ./build-app.sh         # release build → build/Multi-Month Mini Calendar.app
#         open "build/Multi-Month Mini Calendar.app"
#
set -euo pipefail

APP_NAME="Multi-Month Mini Calendar"
EXECUTABLE="MultiMonthMiniCalendar"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release --product "$EXECUTABLE"

BIN_PATH="$(swift build -c release --product "$EXECUTABLE" --show-bin-path)/$EXECUTABLE"

echo "==> Assembling app bundle: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> Bundling resources (holiday data)"
BIN_DIR="$(dirname "$BIN_PATH")"
# SwiftPM emits a resource bundle for the target. It must live under
# Contents/Resources — the only spot that both code-signs cleanly and is found
# by Bundle.holidayResources (which checks Bundle.main.resourceURL first).
# Do NOT also copy it into Contents/MacOS: codesign treats anything there as
# Mach-O code and refuses to seal a resource bundle, producing a broken
# signature that macOS rejects with no "Open Anyway" option.
for RES_BUNDLE in "$BIN_DIR"/*.bundle; do
    [ -e "$RES_BUNDLE" ] || continue
    cp -R "$RES_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
done

echo "==> Ad-hoc code signing"
# `swift build` leaves the binary linker-signed with a flag that claims sealed
# resources exist. Strip that first, otherwise sealing the app produces the
# "code has no resources but signature indicates they must be present" mismatch
# that macOS rejects with no "Open Anyway" option. Then sign the whole app once
# (no `--deep`): the flat SwiftPM resource bundle is sealed as plain resource
# files, which is correct — it has no Info.plist to be signed as a bundle.
codesign --remove-signature "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE" 2>/dev/null || true
codesign --force --sign - "$APP_BUNDLE"
echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP_BUNDLE"

echo "==> Creating distributable zip"
# `ditto` preserves the bundle's symlinks/metadata (plain `zip` corrupts .app).
ZIP_PATH="$BUILD_DIR/Multi-Month-Mini-Calendar.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "==> Done: $APP_BUNDLE"
echo "    Launch with:  open \"$APP_BUNDLE\""
echo "    Distributable: $ZIP_PATH"
