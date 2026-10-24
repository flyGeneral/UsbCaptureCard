#!/bin/bash
# 构建 release(debug 传参即可)并组装 .app bundle + ad-hoc 签名。
# 只依赖 Command Line Tools(swift / codesign),无需完整 Xcode。
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="UsbCaptureCard"
APP_DIR="build/$CONFIG/$APP_NAME.app"

echo "▸ swift build -c $CONFIG"
swift build -c "$CONFIG"

echo "▸ 组装 $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/$CONFIG/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Support/Info.plist "$APP_DIR/Contents/Info.plist"

# ad-hoc 签名:无需开发者账号;bundle id 固定,TCC 权限归属稳定
/usr/bin/codesign --force --sign - --timestamp=none "$APP_DIR"

echo "✅ $APP_DIR"
