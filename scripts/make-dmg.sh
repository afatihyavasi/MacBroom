#!/usr/bin/env bash
#
# Package build/MacBroom.app into build/MacBroom-<version>.dmg with a drag-to-
# Applications layout. Run scripts/make-app.sh first.
#
# Usage: scripts/make-dmg.sh [version]
set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/MacBroom.app"
DMG="$BUILD/MacBroom-${VERSION}.dmg"
STAGE="$BUILD/dmg-stage"

[[ -d "$APP" ]] || { echo "missing $APP — run scripts/make-app.sh first"; exit 1; }

echo "==> staging DMG contents"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> creating $DMG"
hdiutil create \
    -volname "MacBroom" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGE"
echo "==> done: $DMG"
