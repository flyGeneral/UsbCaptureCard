import os

enum Log {
    private static let subsystem = "com.chenjinghao.UsbCaptureCard"
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let discovery = Logger(subsystem: subsystem, category: "discovery")
}
