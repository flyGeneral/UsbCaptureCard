#!/bin/bash
# 构建 Android APK 并复制到 dist/ 作为交付物
# 用法: Scripts/build-apk.sh [debug|release-unsigned]
set -euo pipefail
cd "$(dirname "$0")/../android"

CONFIG="${1:-debug}"

# Gradle 8.11 最高支持 JDK 21;本机 Android Studio JBR 是 25(不兼容),优先 JDK 17
if /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
  export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 17)}"
elif /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
  export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21)}"
else
  export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home)}"
fi

./gradlew :app:assembleDebug --console=plain

VERSION=$(sed -nE 's/.*versionName = "([^"]+)".*/\1/p' app/build.gradle.kts)
SRC=app/build/outputs/apk/debug/app-debug.apk
DST="../dist/UsbCaptureCard-${VERSION}-android.apk"
mkdir -p ../dist
cp -f "$SRC" "$DST"
echo
echo "APK 已输出: $(cd .. && pwd)/dist/UsbCaptureCard-${VERSION}-android.apk"
echo "安装方式: 平板用文件管理器打开 APK → 允许安装未知来源 → 安装"
