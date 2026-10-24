@preconcurrency import AVFoundation
import Foundation

/// 采集会话核心:持有 AVCaptureSession,所有重配置/启停固定走专用串行队列,
/// 会话状态变化回主线程更新(@Observable 驱动 UI)。
@MainActor
@Observable
final class CaptureSessionManager {
    enum Phase: Equatable {
        case idle
        case requestingAccess
        case noPermission
        case noDevice
        case configuring
        case running
        case failed(String)
    }

    struct RecordingNotice: Equatable {
        let url: URL
        let message: String?   // nil = 录制成功
    }

    // MARK: - UI 可观察状态

    private(set) var phase: Phase = .idle
    private(set) var isRecording = false
    private(set) var recordingStartedAt: Date?
    private(set) var activeFormatLabel: String = ""
    private(set) var notice: RecordingNotice?
    /// 预览视图一旦挂载就不再卸载:重建/销毁 preview layer 都会在主线程触发
    /// session 配置互锁,是切换设备卡死的根源
    private(set) var previewMounted = false

    var volume: Float = 1 {
        didSet { audioMonitor.volume = volume }
    }
    var muted = false {
        didSet { audioMonitor.muted = muted }
    }

    // MARK: - AVFoundation 对象(非观察属性)
    // 以下对象由专用串行队列(sessionQueue)管辖,标记 nonisolated(unsafe)
    // 以便在队列闭包中访问;运行时纪律:只在该队列上触碰 session 及其 input/output。

    @ObservationIgnored nonisolated(unsafe) let session = AVCaptureSession()
    /// 供预览层把挂载动作排队到同一串行队列(与设备配置串行,避免互锁)
    @ObservationIgnored nonisolated(unsafe) let sessionQueue = DispatchQueue(
        label: "com.chenjinghao.UsbCaptureCard.session", qos: .userInitiated
    )
    @ObservationIgnored nonisolated(unsafe) private let audioMonitor = AudioMonitor()
    @ObservationIgnored nonisolated(unsafe) private let recorder = Recorder()
    /// activate 代数:看门狗只对最新一次生效
    @ObservationIgnored private var activateGeneration = 0

    init() {
        recorder.onFinished = { [weak self] url, error in
            self?.handleRecordingFinished(url: url, error: error)
        }
    }

    /// 供 AppState 在设备清空时标记空状态
    func markNoDevice() {
        if phase != .running { phase = .noDevice }
    }

    // MARK: - 权限

    func requestAccess() async {
        if phase == .running { return }
        phase = .requestingAccess
        Log.capture.info("请求摄像头权限…")
        let videoGranted = await AVCaptureDevice.requestAccess(for: .video)
        Log.capture.info("摄像头权限:\(videoGranted ? "已授权" : "被拒")")
        // 音频被拒也允许纯视频运行
        let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
        Log.capture.info("麦克风权限:\(audioGranted ? "已授权" : "被拒")")
        if !videoGranted {
            phase = .noPermission
            return
        }
        // 设备选择/启动由 AppState 决定
        phase = .idle
    }

    // MARK: - 会话配置(核心调用序列)

    /// 切换设备/格式/音频源时重复调用;内部幂等(移除旧输入 → 挂新输入 → 应用格式 → 启动)
    func activate(video: AVCaptureDevice, audio: AVCaptureDevice?, format: FormatOption?) {
        if isRecording { recorder.stop() }
        phase = .configuring
        let generation = activateGeneration
        activateGeneration += 1
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let session = self.session

            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }

            var videoOK = false
            do {
                let videoInput = try AVCaptureDeviceInput(device: video)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                    videoOK = true
                } else {
                    Log.capture.error("canAddInput(video) == false")
                }
            } catch {
                Log.capture.error("视频输入创建失败:\(error.localizedDescription)")
            }

            if let audio {
                if let audioInput = try? AVCaptureDeviceInput(device: audio), session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                } else {
                    Log.capture.error("音频输入不可用,回退纯视频")
                }
            }

            if !session.outputs.contains(self.audioMonitor.output), session.canAddOutput(self.audioMonitor.output) {
                session.addOutput(self.audioMonitor.output)
            }
            if !session.outputs.contains(self.recorder.output), session.canAddOutput(self.recorder.output) {
                session.addOutput(self.recorder.output)
            }
            session.commitConfiguration()

            // 格式在 commit 之后按设备级 lockForConfiguration 设置;
            // 设置 activeFormat 会隐式把 preset 切到 inputPriority,此后不要再动 preset
            VideoFormatSelector.apply(format, to: video)

            if !session.isRunning {
                session.startRunning()   // 阻塞调用,已在后台串行队列
            }

            DispatchQueue.main.async {
                if videoOK, session.isRunning {
                    self.phase = .running
                    self.activeFormatLabel = format?.label ?? ""
                    self.previewMounted = true
                } else if videoOK {
                    self.phase = .failed("采集会话启动失败,请重新插拔采集卡后重试")
                } else {
                    self.phase = .failed("无法打开视频设备,请重新插拔采集卡后重试")
                }
            }
        }
        // 看门狗:个别 UVC 设备僵死时 startRunning 可能永久挂起,
        // 20 秒后仍卡在 configuring 则提示用户(用全局队列,sessionQueue 忙时也能触发)
        DispatchQueue.global().asyncAfter(deadline: .now() + 20) { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.activateGeneration == generation, self.phase == .configuring else { return }
                self.phase = .failed("设备启动超时(超过 20 秒),请重新插拔采集卡后重试")
            }
        }
    }

    /// 当前使用的设备被拔出:停录制、停会话
    func handleActiveDeviceRemoved() {
        if isRecording { recorder.stop() }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.phase = .noDevice
            }
        }
    }

    // MARK: - 录制

    func toggleRecording() {
        guard phase == .running else { return }
        if isRecording {
            recorder.stop()
        } else {
            recorder.start()
            isRecording = true
            recordingStartedAt = Date()
            Log.capture.info("开始录制")
        }
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: - 录制完成回调(主线程)

    private func handleRecordingFinished(url: URL, error: Error?) {
        isRecording = false
        recordingStartedAt = nil
        notice = RecordingNotice(url: url, message: Self.friendlyMessage(for: error))
        let ok = notice?.message == nil
        Log.capture.info("录制结束 \(ok ? "成功" : "异常"):\(url.path)")
    }

    /// 部分错误(达到时长/文件上限但文件有效)不算失败
    private static func friendlyMessage(for error: Error?) -> String? {
        guard let error else { return nil }
        let ns = error as NSError
        if ns.userInfo["AVErrorRecordingSuccessfullyFinishedKey"] as? Bool == true {
            return nil
        }
        return ns.localizedDescription
    }
}
