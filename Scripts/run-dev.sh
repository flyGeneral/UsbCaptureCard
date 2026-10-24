#!/bin/bash
# 开发循环:构建 debug → 组 .app → open 启动。
# 一律通过 .app 启动(而不是 swift run):TCC 摄像头/麦克风权限才会归属 app 自己,
# 裸二进制跑权限会归到终端,可能出现静默拒绝。
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/make-app.sh debug

if pgrep -x UsbCaptureCard >/dev/null 2>&1; then
    echo "▸ 结束旧实例"
    pkill -x UsbCaptureCard || true
    sleep 0.5
fi
open "build/debug/UsbCaptureCard.app"
