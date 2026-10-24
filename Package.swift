// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "UsbCaptureCard",
    platforms: [.macOS(.v14)],
    targets: [
        // 语言模式用 v5:AVFoundation 的 session/delegate 对象需跨队列共享,
        // 强行上 Swift 6 严格并发收益低、摩擦大;运行时仍按"session 专用串行队列"约束使用。
        .executableTarget(
            name: "UsbCaptureCard",
            path: "Sources/UsbCaptureCard",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
