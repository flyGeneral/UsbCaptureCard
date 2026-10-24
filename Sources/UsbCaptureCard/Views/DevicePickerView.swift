import SwiftUI

/// 顶部栏:视频设备 / 格式 / 音频源三个下拉
struct DevicePickerBar: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 12) {
            // 视频设备
            Menu {
                ForEach(state.videoDevices, id: \.uniqueID) { device in
                    Button(device.localizedName + (device.isExternalDevice ? "" : "(内置)")) {
                        state.select(videoID: device.uniqueID)
                    }
                }
            } label: {
                Label(state.currentVideoName, systemImage: "video")
                    .lineLimit(1)
            }
            .fixedSize()

            // 格式(W×H @ fps · 编码)
            Menu {
                ForEach(state.formatOptions) { option in
                    Button(option.label) {
                        state.select(formatID: option.id)
                    }
                }
            } label: {
                Label(state.capture.activeFormatLabel.isEmpty ? "格式" : state.capture.activeFormatLabel,
                      systemImage: "aspectratio")
                    .lineLimit(1)
            }
            .fixedSize()

            // 音频源
            Menu {
                Button("自动配对(推荐)") { state.select(audioID: "__auto__") }
                Button("无音频") { state.select(audioID: "__none__") }
                Divider()
                ForEach(state.audioDevices, id: \.uniqueID) { device in
                    Button(device.localizedName + (device.isExternalDevice ? "" : "(内置)")) {
                        state.select(audioID: device.uniqueID)
                    }
                }
            } label: {
                Label("音频", systemImage: "waveform")
            }
            .fixedSize()

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

/// 底部控制条:录制 / 静音 / 音量 / 置顶 / 全屏
struct ControlBar: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        return HStack(spacing: 16) {
            RecordButton()

            Button {
                state.muted.toggle()
            } label: {
                Image(systemName: state.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .help(state.muted ? "取消静音" : "静音")

            Slider(value: $state.volume, in: 0...1)
                .frame(width: 110)
                .help("监听音量")

            Spacer()

            Button {
                state.setAlwaysOnTop(!state.alwaysOnTop)
            } label: {
                Image(systemName: "pin")
                    .opacity(state.alwaysOnTop ? 1 : 0.35)
            }
            .buttonStyle(.borderless)
            .help(state.alwaysOnTop ? "取消窗口置顶" : "窗口置顶")

            Button {
                NSApp.keyWindow?.toggleFullScreen(nil)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .help("全屏")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct RecordButton: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let recording = state.capture.isRecording
        return Button {
            state.capture.toggleRecording()
        } label: {
            ZStack {
                if recording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.red)
                        .frame(width: 13, height: 13)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(recording ? "停止录制" : "开始录制(保存到 ~/Movies/UsbCaptureCard)")
    }
}
