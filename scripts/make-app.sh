#!/usr/bin/env bash
#
# Assemble MacBroom.app from the SwiftPM executable plus the bundled engine and
# mole library. Produces build/MacBroom.app.
#
# Usage: scripts/make-app.sh [version]
set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/MacBroom.app"
CONTENTS="$APP/Contents"
RES="$CONTENTS/Resources"
MACOS="$CONTENTS/MacOS"

echo "==> swift build (release)"
( cd "$ROOT/app" && swift build -c release --product MacBroom )
BIN="$ROOT/app/.build/release/MacBroom"
[[ -x "$BIN" ]] || { echo "build failed: $BIN missing"; exit 1; }

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES/vendor/mole"

cp "$BIN" "$MACOS/MacBroom"

# Engine + mole library (only lib/ + LICENSE are needed at runtime).
cp "$ROOT/engine/macbroom-engine.sh" "$RES/macbroom-engine.sh"
chmod +x "$RES/macbroom-engine.sh"
cp -R "$ROOT/vendor/mole/lib" "$RES/vendor/mole/lib"
cp "$ROOT/vendor/mole/LICENSE" "$RES/vendor/mole/LICENSE" 2>/dev/null || true

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MacBroom</string>
    <key>CFBundleDisplayName</key><string>MacBroom</string>
    <key>CFBundleIdentifier</key><string>com.macbroom.app</string>
    <key>CFBundleExecutable</key><string>MacBroom</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>GPL-3.0. Cleaning engine: tw93/mole (GPL-3.0).</string>
</dict>
</plist>
PLIST

echo "==> done: $APP"
