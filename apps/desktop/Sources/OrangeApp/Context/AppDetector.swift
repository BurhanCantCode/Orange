import AppKit
import Foundation

struct AppDetector {
    func currentApp() -> AppMetadata {
        let app = NSWorkspace.shared.frontmostApplication
        return AppMetadata(
            name: app?.localizedName,
            bundleId: app?.bundleIdentifier,
            windowTitle: nil,
            url: nil
        )
    }
}
