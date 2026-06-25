#!/usr/bin/env bash
#
# Assemble MacBroom.app from the SwiftPM executable plus the bundled engine and
# mole library. Produces build/MacBroom.app.
#
# Usage: scripts/make-app.sh [version]
set -euo pipefail

VERSION="${1:-1.0.0}"
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

# App icon. Build assets/AppIcon.icns on demand (from assets/AppIcon.png, or a
# generated starter), then bundle it. To use your own logo, drop a 1024×1024
# PNG at assets/AppIcon.png and re-run (or run scripts/make-icon.sh).
[[ -f "$ROOT/assets/AppIcon.icns" ]] || "$ROOT/scripts/make-icon.sh"
cp "$ROOT/assets/AppIcon.icns" "$RES/AppIcon.icns"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MacBroom</string>
    <key>CFBundleDisplayName</key><string>MacBroom</string>
    <key>CFBundleIdentifier</key><string>com.macbroom.app</string>
    <key>CFBundleExecutable</key><string>MacBroom</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>GPL-3.0. Cleaning engine: tw93/mole (GPL-3.0).</string>
</dict>
</plist>
PLIST

# Code signing.
#
# `swift build` linker-signs ONLY the inner executable (ad-hoc). Once we add the
# Info.plist + Resources, that lone signature no longer matches the bundle, so
# the seal is inconsistent ("code has no resources but signature indicates they
# must be present") and macOS reports the downloaded app as **"damaged"** on
# Apple Silicon. We therefore ALWAYS sign the *assembled bundle*:
#   - With a Developer ID (MACBROOM_SIGN_IDENTITY) → distribution signing
#     (hardened runtime + timestamp), ready for notarization.
#   - Otherwise → an ad-hoc signature that seals the bundle. The app is still
#     unsigned-for-distribution, but it's valid, so Gatekeeper shows the normal
#     "unidentified developer" prompt (right-click → Open) instead of "damaged".
if [[ -n "${MACBROOM_SIGN_IDENTITY:-}" ]]; then
  echo "==> codesign (Developer ID, hardened runtime + timestamp)"
  codesign --force --deep --options runtime --timestamp \
    --sign "$MACBROOM_SIGN_IDENTITY" "$APP"
else
  echo "==> codesign (ad-hoc — seals the bundle so it isn't flagged as damaged)"
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"

echo "==> done: $APP"
