import AVFoundation

extension AVCaptureDevice {
    /// 当前 SDK 无 isExternal,按设备类型判断是否外部设备(采集卡)
    var isExternalDevice: Bool { deviceType == .external }
}

/// 一次性设备扫描结果:外部采集卡 + 内置摄像头/麦克风(内置仅作管线测试)
struct DeviceCatalog {
    let videos: [AVCaptureDevice]
    let audios: [AVCaptureDevice]

    static func scan() -> DeviceCatalog {
        // .external 覆盖 UVC 采集卡;.builtInWideAngleCamera 覆盖 FaceTime 摄像头(测试管线用)
        let videoSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        // 音频:UAC 声卡 + 内置麦克风
        let audioSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .microphone],
            mediaType: .audio,
            position: .unspecified
        )
        let catalog = DeviceCatalog(videos: videoSession.devices, audios: audioSession.devices)
        Log.discovery.info("扫描:视频 \(catalog.videos.count) 个,音频 \(catalog.audios.count) 个")
        return catalog
    }

    /// UVC↔UAC 配对:优先 VID 匹配(同一张卡的音频 uniqueID 里含厂商 ID),
    /// 失败时若恰好只有一个外部音频设备则直接配对,否则交由用户手选。
    static func suggestedAudio(for video: AVCaptureDevice, in audios: [AVCaptureDevice]) -> AVCaptureDevice? {
        if let vid = vendorID(of: video) {
            let hex = String(vid, radix: 16)
            let hit = audios.first { audio in
                let uid = audio.uniqueID
                return uid.localizedCaseInsensitiveContains("vendorid:0x\(hex)")
                    || (uid.localizedCaseInsensitiveContains(hex) && uid.localizedCaseInsensitiveContains("usb"))
            }
            if let hit {
                Log.discovery.info("VID 0x\(hex) 配对音频:\(hit.localizedName)")
                return hit
            }
        }
        let externals = audios.filter { $0.isExternalDevice }
        return externals.count == 1 ? externals[0] : nil
    }

    /// modelID 形如 "UVC Camera VendorID_1453 ProductID_8496",取十进制 VendorID
    static func vendorID(of device: AVCaptureDevice) -> Int? {
        for part in device.modelID.split(separator: " ") {
            if part.hasPrefix("VendorID_"), let value = Int(part.dropFirst("VendorID_".count)) {
                return value
            }
        }
        return nil
    }
}
