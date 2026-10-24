import SwiftUI

/// 右上角角标:当前格式 + 录制中红点计时
struct StatsOverlay: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if state.capture.isRecording {
                RecordingBadge()
            }
            if !state.capture.activeFormatLabel.isEmpty {
                Text(state.capture.activeFormatLabel)
                    .font(.caption)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(12)
        .animation(.easeInOut(duration: 0.15), value: state.capture.isRecording)
    }
}

struct RecordingBadge: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text(Self.elapsedText(since: state.capture.recordingStartedAt, now: timeline.date))
            }
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.red.opacity(0.75), in: Capsule())
        }
    }

    private static func elapsedText(since: Date?, now: Date) -> String {
        guard let since else { return "00:00" }
        let seconds = max(0, Int(now.timeIntervalSince(since).rounded(.down)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// 录制结束提示:成功则可在 Finder 中查看
struct RecordingNoticeView: View {
    @Environment(AppState.self) private var state
    let notice: CaptureSessionManager.RecordingNotice

    var body: some View {
        VStack(spacing: 4) {
            if let message = notice.message {
                Label("录制异常:\(message)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            } else {
                Label("已保存录制", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Text(notice.url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([notice.url])
                }
                Button("关闭") {
                    state.capture.dismissNotice()
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 76)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
