#!/usr/bin/env bash
#
# Package build/MacBroom.app into build/MacBroom-<version>.dmg with a drag-to-
# Applications layout. Run scripts/make-app.sh first.
#
# Usage: scripts/make-dmg.sh [version]
set -euo pipefail

VERSION="${1:-1.0.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/MacBroom.app"
DMG="$BUILD/MacBroom-${VERSION}.dmg"
STAGE="$BUILD/dmg-stage"

[[ -d "$APP" ]] || { echo "missing $APP — run scripts/make-app.sh first"; exit 1; }

echo "==> staging DMG contents"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
# ditto (not cp -R) preserves extended attributes and the code-signature
# metadata exactly; a copy that drops them invalidates the bundle seal and
# macOS then reports the downloaded app as "damaged".
ditto "$APP" "$STAGE/MacBroom.app"
ln -s /Applications "$STAGE/Applications"

# First-launch help for unsigned builds: quarantined ad-hoc-signed apps are
# reported as "damaged" by Gatekeeper on Apple Silicon, and right-click → Open
# does NOT bypass that dialog. Ship the one-line fix inside the DMG.
cat > "$STAGE/If macOS says MacBroom is damaged - READ ME.txt" <<'TXT'
If macOS says: "MacBroom is damaged and can't be opened"
=========================================================

This build is not notarized with an Apple Developer ID yet, so Gatekeeper
blocks the downloaded app (right-click -> Open does not help for this dialog).
The app is fine — you only need to clear the quarantine flag once.

1. Drag MacBroom.app into the Applications folder.
2. Open Terminal and run:

   xattr -d com.apple.quarantine /Applications/MacBroom.app

3. Launch MacBroom — the broom icon appears in the menu bar (top right).

Alternatively, install via Homebrew, which handles this automatically:

   brew install --cask afatihyavasi/tap/macbroom
TXT

echo "==> creating $DMG"
hdiutil create \
    -volname "MacBroom" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGE"
echo "==> done: $DMG"
