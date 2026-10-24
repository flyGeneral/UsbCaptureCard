import SwiftUI

/// 未检测到采集卡的空状态:接入指引 + 内置摄像头管线测试入口
struct EmptyStateView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.and.hifi")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("未检测到采集卡")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("将 USB 采集卡插入 Mac(USB 3 口更佳)", systemImage: "1.circle")
                Label("HDMI 线连接 Switch 2 底座 → 采集卡输入口", systemImage: "2.circle")
                Label("Switch 2 设置 → 主机 → 屏幕输出 → TV 分辨率选 1080p(可采到 60fps)", systemImage: "3.circle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            if let builtin = state.videoDevices.first(where: { !$0.isExternalDevice }) {
                Button("使用内置摄像头测试预览管线") {
                    state.select(videoID: builtin.uniqueID)
                }
                .padding(.top, 4)
            }
        }
        .padding(32)
    }
}

/// 正在请求权限:弹窗未弹出/被挡住时也始终有出路,不会停在死转圈
struct RequestingAccessView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("正在请求摄像头/麦克风权限…")
                .font(.title3)
            Text("若没有看到系统弹窗,可能是弹窗被其他窗口挡住了(Cmd+Tab 切到最前)\n或此前拒绝过,请到系统设置中手动允许")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("打开系统设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("重新请求") {
                    Task { await AppState.shared.bootstrap() }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 460)
    }
}

/// 摄像头权限被拒
struct PermissionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("需要摄像头权限").font(.title3.bold())
            Text("请在 系统设置 → 隐私与安全性 → 摄像头 中允许「采集卡预览」")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("打开系统设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("重试") {
                    Task { await AppState.shared.bootstrap() }
                }
            }
        }
        .padding(32)
    }
}

/// 会话启动失败
struct ErrorView: View {
    @Environment(AppState.self) private var state
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("重试") {
                Task { await AppState.shared.bootstrap() }
            }
        }
        .padding(32)
    }
}
