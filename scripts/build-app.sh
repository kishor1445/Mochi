#!/usr/bin/env bash
# Builds a double-clickable Mochi.app into ./dist (menu-bar app, no Dock icon).
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
APP="dist/Mochi.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Mochi"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Mochi"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Mochi</string>
    <key>CFBundleDisplayName</key><string>Mochi</string>
    <key>CFBundleIdentifier</key><string>com.mochi.pet</string>
    <key>CFBundleExecutable</key><string>Mochi</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so it launches without "damaged app" errors on the machine that built it.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: codesign failed (app may need to be allowed manually)"

echo "Built $APP"
