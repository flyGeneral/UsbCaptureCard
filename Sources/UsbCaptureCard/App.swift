import SwiftUI

@main
struct UsbCaptureCardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("UsbCaptureCard — 采集卡预览") {
            ContentView()
                .environment(AppState.shared)
        }
        .defaultSize(width: 1120, height: 630)
        .commands {
            CommandMenu("显示") {
                Toggle("窗口置顶", isOn: Binding(
                    get: { AppState.shared.alwaysOnTop },
                    set: { AppState.shared.setAlwaysOnTop($0) }
                ))
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                Button("进入全屏") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
            }
        }
    }
}
