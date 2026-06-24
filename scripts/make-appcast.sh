#!/usr/bin/env bash
#
# Generate (and EdDSA-sign) appcast.xml for the DMG(s) in a release directory,
# using Sparkle's generate_appcast from the SPM build artifacts. The private
# signing key is read from the macOS keychain — set it up ONCE with Sparkle's
# generate_keys (see docs/RELEASING.md). Upload the resulting appcast.xml next
# to the DMG so SUFeedURL can reach it.
#
# Usage: scripts/make-appcast.sh <dir-with-dmgs>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${1:?usage: scripts/make-appcast.sh <dir-with-dmgs>}"

GEN="$(find "$ROOT/app/.build/artifacts" -type f -name "generate_appcast" 2>/dev/null | head -1)"
[[ -x "$GEN" ]] || { echo "generate_appcast not found — run 'swift build' in app/ first"; exit 1; }

echo "==> generate_appcast $DIR"
"$GEN" "$DIR"
echo "==> appcast.xml written in $DIR — upload it with the DMG"
