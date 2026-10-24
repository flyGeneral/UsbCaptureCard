# UsbCaptureCard

游戏采集录制工具:通过采集卡捕获游戏机(如 Switch 2)画面与音频,在 Mac / Android 平板上完成实时预览、录制。

Game Capture & Recorder: capture video and audio from game consoles via a USB capture card, with real-time preview and recording on Mac and Android tablets.

## Mac 端(Swift / SPM)

见 `Sources/UsbCaptureCard/`。

- 开发调试:`Scripts/run-dev.sh`(构建 + 组 .app + 启动,摄像头权限归属正确)
- 打包发布:`Scripts/make-app.sh release` + `Scripts/make-dmg.sh` → `dist/UsbCaptureCard-x.y.z.dmg`
- 功能:格式选择(1080p60 优先)、音频监听(音量/静音)、MP4 录制、热插拔、窗口置顶

## Android 端(AUSBC 3.2.7 / Kotlin)

见 `android/`。平板通过 **USB-OTG 线直连采集卡**,无需电脑。

- 构建:`Scripts/build-apk.sh` → `dist/UsbCaptureCard-x.y.z-android.apk`(debug 签名,可直接安装)
- 安装:APK 拷到平板(文件管理器打开 → 允许未知来源)。无 adb 要求
- 使用:OTG 线接采集卡 → HDMI 接 Switch 2 底座 → 首次启动授予"相机"权限(AUSBC 3.2.7 的门槛,见下) → 插卡时允许 USB 权限弹窗 → 自动出画面和声音
- 功能:1080p 预览(MJPEG,带宽不足可切 720p)、音频监听/静音、MP4 录制(保存到应用 Movies 目录)、热插拔自动恢复
- 排障:无法出图时 `adb logcat -s CameraUvcStrategy:V CameraClient:V` 查看

### 为什么是 AUSBC 3.2.7(而不是 3.3.x)

- JitPack 上 3.2.8 起(含 3.3.x)发布损坏:libnative 只有 pom,二进制 404
- 3.2.7 传递依赖 `com.gyf.immersionbar` / `com.zlc.glide:webpdecoder` 已在 JitPack 下架(401),已在 `app/build.gradle.kts` 排除(libausbc 源码零引用)
- libausbc 对 libuvc 是 `implementation` 依赖不对外导出,必须显式加 `libuvc:3.2.7`
- 3.2.7 的 `CameraClient.openCamera` 要求 CAMERA 运行时权限(UVC 也一样),应用启动时会请求,授权后自动重试开启预览

## 硬件注意事项

- Switch 2 需在主机设置中把 TV 输出设为 **1080p** 才能采到 60fps(输出 4K 时卡只能 4K30)
- MS2130 类 4K 卡:USB3 口可能只暴露 YUYV,USB2 口通常只有 MJPG;两端都做了格式自适应
