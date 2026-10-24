#!/bin/bash
# 出分发用 DMG:release .app + Applications 软链,hdiutil UDZO 压缩。
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/make-app.sh release

STAGING="build/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "build/release/UsbCaptureCard.app" "$STAGING/"
ln -sfn /Applications "$STAGING/Applications"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "build/release/UsbCaptureCard.app/Contents/Info.plist")
mkdir -p dist
DMG="dist/UsbCaptureCard-$VERSION.dmg"
rm -f "$DMG"

echo "▸ hdiutil create"
hdiutil create -volname "UsbCaptureCard" -srcfolder "$STAGING" -ov -format UDZO "$DMG" -quiet

echo "✅ $DMG"
