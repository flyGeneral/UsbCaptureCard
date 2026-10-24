import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // 预览一旦挂载永不卸载:重建/销毁 preview layer 都会触发 session 配置互锁
            if state.capture.previewMounted {
                PreviewView(session: state.capture.session, sessionQueue: state.capture.sessionQueue)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            }
            switch state.capture.phase {
            case .idle, .requestingAccess:
                RequestingAccessView()
            case .noPermission:
                PermissionView()
            case .noDevice:
                EmptyStateView()
            case .configuring:
                ProgressView("正在启动采集…")   // 叠加在预览之上,不替换预览视图
            case .running:
                EmptyView()
            case .failed(let message):
                ErrorView(message: message)
            }
        }
        .frame(minWidth: 720, minHeight: 405)
        .task { await state.bootstrap() }
        .overlay(alignment: .top) {
            if state.capture.phase == .running { DevicePickerBar() }
        }
        .overlay(alignment: .bottom) {
            if state.capture.phase == .running { ControlBar() }
        }
        .overlay(alignment: .topTrailing) {
            if state.capture.phase == .running { StatsOverlay() }
        }
        .overlay(alignment: .bottom) {
            if let notice = state.capture.notice { RecordingNoticeView(notice: notice) }
        }
        .onChange(of: state.alwaysOnTop) { _, _ in
            state.applyWindowLevel()
        }
    }
}
