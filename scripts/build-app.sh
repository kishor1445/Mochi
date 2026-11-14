#!/usr/bin/env bash
# Builds a double-clickable Mochi.app into ./dist (menu-bar app, no Dock icon).
set -euo pipefail

cd "$(dirname "$0")/.."
APP="dist/Mochi.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Mochi"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Mochi"
cp Support/Info.plist "$APP/Contents/Info.plist"

# VERSION=1.2.3 ./scripts/build-app.sh overrides the version in Support/Info.plist.
if [[ -n "${VERSION:-}" ]]; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
fi

# Ad-hoc sign so it launches without "damaged app" errors on the machine that built it.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: codesign failed (app may need to be allowed manually)"

echo "Built $APP"
