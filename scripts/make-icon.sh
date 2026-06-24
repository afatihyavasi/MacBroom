#!/usr/bin/env bash
#
# Build assets/AppIcon.icns from a 1024×1024 source PNG (assets/AppIcon.png).
# If the source PNG is missing, a starter icon is generated. To use your own
# logo: drop a 1024×1024 PNG at assets/AppIcon.png and re-run this script.
#
# Requires only macOS built-ins: sips + iconutil.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$ROOT/assets"
SRC="$ASSETS/AppIcon.png"
ICNS="$ASSETS/AppIcon.icns"
ICONSET="$(mktemp -d)/AppIcon.iconset"

mkdir -p "$ASSETS" "$ICONSET"

if [[ ! -f "$SRC" ]]; then
    echo "==> no $SRC — generating a starter icon"
    swift "$ROOT/scripts/_gen_icon.swift" "$SRC"
fi

echo "==> rendering iconset sizes from $SRC"
# macOS .iconset requires these exact names/sizes.
gen() { sips -z "$2" "$2" "$SRC" --out "$ICONSET/icon_$1.png" >/dev/null; }
gen 16x16        16
gen 16x16@2x     32
gen 32x32        32
gen 32x32@2x     64
gen 128x128     128
gen 128x128@2x  256
gen 256x256     256
gen 256x256@2x  512
gen 512x512     512
gen 512x512@2x 1024

echo "==> iconutil → $ICNS"
iconutil --convert icns "$ICONSET" --output "$ICNS"
rm -rf "$(dirname "$ICONSET")"
echo "==> done: $ICNS"
