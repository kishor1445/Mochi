#!/usr/bin/env bash
# Builds Mochi.app and packages it into dist/Mochi-<version>.dmg (drag Mochi onto Applications).
# VERSION=1.2.3 ./scripts/build-dmg.sh overrides the version in Support/Info.plist.
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build-app.sh

APP="dist/Mochi.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
DMG="dist/Mochi-${VERSION}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/Mochi.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "Mochi" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null

echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
