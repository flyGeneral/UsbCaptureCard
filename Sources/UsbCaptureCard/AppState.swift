import AppKit
@preconcurrency import AVFoundation
import Observation

/// 全局应用状态:设备列表、当前选择、UI 设置;持有 CaptureSessionManager。
/// 通过 AppState.shared 供 SwiftUI Commands / AppDelegate 访问。
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    // MARK: - 设备

    private(set) var videoDevices: [AVCaptureDevice] = []
    private(set) var audioDevices: [AVCaptureDevice] = []

    var selectedVideoID: String?
    var selectedFormatID: String?
    /// "__auto__"(默认,自动配对)/ "__none__" / 具体音频设备 uniqueID
    var selectedAudioID = "__auto__"

    let capture = CaptureSessionManager()

    // MARK: - UI 设置(持久化)

    private(set) var alwaysOnTop: Bool
    var volume: Float {
        didSet {
            capture.volume = volume
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }
    var muted: Bool {
        didSet {
            capture.muted = muted
            UserDefaults.standard.set(muted, forKey: "muted")
        }
    }

    @ObservationIgnored private var hotPlugObservers: [NSObjectProtocol] = []

    // MARK: - 派生

    var currentVideoDevice: AVCaptureDevice? {
        videoDevices.first { $0.uniqueID == selectedVideoID }
    }

    var currentAudioDevice: AVCaptureDevice? {
        let id = selectedAudioID
        guard id != "__none__" else { return nil }
        if id == "__auto__" {
            return currentVideoDevice.flatMap { DeviceCatalog.suggestedAudio(for: $0, in: audioDevices) }
        }
        return audioDevices.first { $0.uniqueID == id }
    }

    /// 格式列表缓存:device.formats 的访问可能阻塞在异常 UVC 设备上,
    /// 不能在主线程/SwiftUI body 里现查;换设备时在后台线程读取
    private(set) var formatOptions: [FormatOption] = []

    func refreshFormatOptions() {
        guard let device = currentVideoDevice else {
            formatOptions = []
            return
        }
        let deviceID = device.uniqueID
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let options = VideoFormatSelector.options(for: device)
            DispatchQueue.main.async {
                guard let self, self.currentVideoDevice?.uniqueID == deviceID else { return }
                self.formatOptions = options
            }
        }
    }

    /// 手选格式;未手选则自动选
    var selectedFormat: FormatOption? {
        if let id = selectedFormatID, let hit = formatOptions.first(where: { $0.id == id }) {
            return hit
        }
        return VideoFormatSelector.automatic(from: formatOptions)
    }

    var currentVideoName: String {
        guard let device = currentVideoDevice else { return "选择设备" }
        return device.localizedName + (device.isExternalDevice ? "" : "(内置)")
    }

    // MARK: - 初始化

    init() {
        let defaults = UserDefaults.standard
        alwaysOnTop = defaults.bool(forKey: "alwaysOnTop")
        volume = defaults.object(forKey: "volume") as? Float ?? 1
        muted = defaults.bool(forKey: "muted")
        capture.volume = volume
        capture.muted = muted
        observeHotPlug()
    }

    // MARK: - 启动流程

    func bootstrap() async {
        await capture.requestAccess()
        guard capture.phase != .noPermission else { return }
        scan()
        autoStartIfPossible()
    }

    /// 只自动启动外部设备(采集卡);没有卡时进空状态,内置摄像头由用户手动选作管线测试
    func autoStartIfPossible() {
        guard capture.phase != .running, capture.phase != .configuring else { return }
        guard let external = videoDevices.first(where: { $0.isExternalDevice }) else {
            capture.markNoDevice()
            return
        }
        selectedVideoID = external.uniqueID
        selectedFormatID = nil
        selectedAudioID = "__auto__"
        refreshFormatOptions()
        start()
    }

    func start() {
        guard let video = currentVideoDevice else {
            capture.markNoDevice()
            return
        }
        capture.activate(video: video, audio: currentAudioDevice, format: selectedFormat)
    }

    // MARK: - 用户选择

    func select(videoID: String) {
        selectedVideoID = videoID
        selectedFormatID = nil          // 换设备重置格式为自动
        selectedAudioID = "__auto__"
        refreshFormatOptions()
        start()
    }

    func select(formatID: String) {
        selectedFormatID = formatID
        start()
    }

    func select(audioID: String) {
        selectedAudioID = audioID
        start()
    }

    // MARK: - 设备扫描与热插拔

    func scan() {
        let catalog = DeviceCatalog.scan()
        videoDevices = catalog.videos
        audioDevices = catalog.audios
    }

    private func observeHotPlug() {
        let center = NotificationCenter.default
        // 回调固定在主队列(queue: .main),assumeIsolated 如实声明
        hotPlugObservers.append(center.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.scan()
                // 空状态下新设备插入 → 自动开始
                if self.capture.phase == .noDevice {
                    self.autoStartIfPossible()
                }
            }
        })
        hotPlugObservers.append(center.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self else { return }
                let removed = notification.object as? AVCaptureDevice
                self.scan()
                if removed?.uniqueID == self.selectedVideoID || self.videoDevices.isEmpty {
                    self.capture.handleActiveDeviceRemoved()
                }
            }
        })
    }

    // MARK: - 窗口置顶

    func setAlwaysOnTop(_ on: Bool) {
        alwaysOnTop = on
        UserDefaults.standard.set(on, forKey: "alwaysOnTop")
        applyWindowLevel()
    }

    func applyWindowLevel() {
        for window in NSApp.windows where window.isVisible {
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
}
