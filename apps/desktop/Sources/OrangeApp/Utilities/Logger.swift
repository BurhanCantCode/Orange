import Foundation
import os.log

enum Logger {
    private static let subsystem = "ai.orange.desktop"
    private static let core = OSLog(subsystem: subsystem, category: "core")

    static func info(_ message: String) {
        os_log("%{public}@", log: core, type: .info, message)
    }

    static func error(_ message: String) {
        os_log("%{public}@", log: core, type: .error, message)
    }
}
