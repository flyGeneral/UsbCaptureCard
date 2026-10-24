import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SPM 可执行文件启动的窗口默认可能不激活,前置之
        NSApp.activate(ignoringOtherApps: true)
        if AppState.shared.alwaysOnTop {
            AppState.shared.applyWindowLevel()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
