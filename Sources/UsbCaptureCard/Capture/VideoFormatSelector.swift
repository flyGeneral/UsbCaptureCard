import AVFoundation
import CoreMedia

/// 一个可选的视频格式条目(W×H @ 最大fps · 编码)
struct FormatOption: Identifiable, Hashable {
    let id: String          // "1920x1080@60-MJPG"
    let label: String       // "1920 × 1080 · 60 fps · MJPG"
    let formatIndex: Int    // 对应 device.formats 下标(仅在该设备实例内有效)
    let width: Int
    let height: Int
    let maxFPS: Double
    let codec: String
}

/// 4K 采集卡默认格式常是低分辨率/低帧率,必须手动选 activeFormat。
/// 注意:设置 activeFormat 会把 session 隐式切到 .inputPriority,之后不要再动 sessionPreset。
enum VideoFormatSelector {
    static func options(for device: AVCaptureDevice) -> [FormatOption] {
        var seen = Set<String>()
        var result: [FormatOption] = []
        for (index, format) in device.formats.enumerated() {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let width = Int(dims.width)
            let height = Int(dims.height)
            let fps = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
            let codec = fourCCString(CMFormatDescriptionGetMediaSubType(format.formatDescription))
            let fpsText = Int(fps.rounded())
            let id = "\(width)x\(height)@\(fpsText)-\(codec)"
            guard seen.insert(id).inserted else { continue }
            result.append(FormatOption(
                id: id,
                label: "\(width) × \(height) · \(fpsText) fps · \(codec)",
                formatIndex: index,
                width: width,
                height: height,
                maxFPS: fps,
                codec: codec
            ))
        }
        // 分辨率大→帧率高 优先
        return result.sorted { lhs, rhs in
            (lhs.width * lhs.height, lhs.maxFPS) > (rhs.width * rhs.height, rhs.maxFPS)
        }
    }

    /// 自动选择优先级:1080p60(游戏最需要)> 1080p > 高帧率 > 分辨率最大。
    /// 游戏场景 60fps 比 4K30 更重要,故 1080p 固定加权最高。
    static func automatic(from options: [FormatOption]) -> FormatOption? {
        guard !options.isEmpty else { return nil }
        func priority(_ o: FormatOption) -> (Int, Int, Double, Int) {
            let is1080 = (o.width == 1920 && o.height == 1080) ? 1 : 0
            let ge60 = o.maxFPS >= 59.5 ? 1 : 0
            let mjpg = o.codec == "MJPG" ? 1 : 0   // USB 带宽友好
            return (is1080, ge60, o.maxFPS, mjpg)
        }
        return options.max { priority($0) < priority($1) }
    }

    /// 应用格式:必须在 lockForConfiguration 内设置 activeFormat + 帧率时长,否则崩溃
    static func apply(_ option: FormatOption?, to device: AVCaptureDevice) {
        guard let option, device.formats.indices.contains(option.formatIndex) else { return }
        let format = device.formats[option.formatIndex]

        // 期望帧时长 = 1/fps;不在格式支持范围内则退到该格式支持的最快帧率
        let desired = CMTime(value: 1, timescale: CMTimeScale(max(1, option.maxFPS.rounded())))
        let inRange = format.videoSupportedFrameRateRanges.contains {
            $0.minFrameDuration <= desired && desired <= $0.maxFrameDuration
        }
        let duration = inRange
            ? desired
            : (format.videoSupportedFrameRateRanges.map(\.minFrameDuration).min() ?? desired)

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.activeFormat = format
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            Log.capture.info("已应用格式 \(option.label)")
        } catch {
            Log.capture.error("格式应用失败:\(error.localizedDescription)")
        }
    }

    static func fourCCString(_ code: FourCharCode) -> String {
        var value = code.bigEndian
        let data = withUnsafeBytes(of: &value) { Data($0) }
        if let text = String(data: data, encoding: .macOSRoman), text.count == 4 {
            return text
        }
        return String(code)
    }
}
