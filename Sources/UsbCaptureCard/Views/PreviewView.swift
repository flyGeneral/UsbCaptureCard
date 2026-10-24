import AVFoundation
import SwiftUI

/// 预览画面:NSViewRepresentable 包装 AVCaptureVideoPreviewLayer(直通 GPU,延迟最低)。
/// 死锁防御(切换设备卡死的根源):
/// - 主线程绝不直接设置 layer.session:addVideoPreviewLayer/removeVideoPreviewLayer 内部
///   都会触发 commitConfiguration,与后台串行队列正在进行的设备重配置互等 → 主线程卡死。
///   因此挂载动作统一排队到 sessionQueue,与设备配置天然串行。
/// - 视图一旦挂载永不重建/卸载(AppState 控制),避免任何销毁路径再次触碰 session。
struct PreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    let sessionQueue: DispatchQueue

    func makeNSView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        let session = self.session
        sessionQueue.async { [weak view] in
            guard let view else { return }
            session.beginConfiguration()
            view.previewLayer.session = session
            session.commitConfiguration()
        }
        return view
    }

    func updateNSView(_ view: PreviewHostView, context: Context) {
        // session 实例恒定不变,无需任何更新
    }
}

final class PreviewHostView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        previewLayer.backgroundColor = NSColor.black.cgColor
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
