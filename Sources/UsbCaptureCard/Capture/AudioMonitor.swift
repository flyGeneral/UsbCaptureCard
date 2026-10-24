import AVFoundation

/// 音频监听:AVCaptureAudioPreviewOutput 把采集卡的 UAC 音频直接混到系统默认输出设备。
/// 注:macOS 27 SDK 已把 AVSampleBufferAudioRenderer.append/flush 迁到
/// sampleBufferReceiver(adding:) + CMReadySampleBuffer 新管线(部分初始化器未公开),
/// MVP 采用官方一行式 AVCaptureAudioPreviewOutput;若后续需要更低延迟/可调音画偏移再迁移。
final class AudioMonitor {
    /// 挂到 session 上的输出(连接音频输入后自动生效,跟随 session 启停)
    let output = AVCaptureAudioPreviewOutput()

    private var storedVolume: Float = 1
    private var isMuted = false

    var volume: Float {
        get { storedVolume }
        set {
            storedVolume = min(1, max(0, newValue))
            apply()
        }
    }

    var muted: Bool {
        get { isMuted }
        set {
            isMuted = newValue
            apply()
        }
    }

    private func apply() {
        output.volume = isMuted ? 0 : storedVolume
    }
}
