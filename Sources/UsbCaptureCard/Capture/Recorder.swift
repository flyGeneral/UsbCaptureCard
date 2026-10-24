import AVFoundation

/// 录制封装:AVCaptureMovieFileOutput(自动处理 MJPG 解码 → H.264 重编码 + AAC 音轨)。
/// 文件落在 ~/Movies/UsbCaptureCard/。
final class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    let output = AVCaptureMovieFileOutput()
    var onFinished: ((URL, Error?) -> Void)?

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()

    static func makeFileURL() -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/UsbCaptureCard")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("capture_\(formatter.string(from: Date())).mov")
    }

    func start() {
        output.startRecording(to: Self.makeFileURL(), recordingDelegate: self)
    }

    func stop() {
        output.stopRecording()
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinished?(outputFileURL, error)
        }
    }
}
