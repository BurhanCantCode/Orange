import AppKit
import ApplicationServices
import Foundation

struct AppDetector {
    func currentApp() -> AppMetadata {
        let app = NSWorkspace.shared.frontmostApplication
        let windowTitle = focusedWindowTitle(for: app)
        let url = activeBrowserURL(for: app?.bundleIdentifier)
        return AppMetadata(
            name: app?.localizedName,
            bundleId: app?.bundleIdentifier,
            windowTitle: windowTitle,
            url: url
        )
    }

    private func focusedWindowTitle(for app: NSRunningApplication?) -> String? {
        guard let app else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        let focusedWindowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &windowRef
        )
        guard focusedWindowResult == .success, let windowRef else { return nil }
        let window = windowRef as! AXUIElement

        var titleRef: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        guard titleResult == .success else { return nil }
        return titleRef as? String
    }

    private func activeBrowserURL(for bundleID: String?) -> String? {
        switch bundleID {
        case "com.apple.Safari":
            return runAppleScript(
                """
                tell application "Safari"
                    if (count of documents) > 0 then
                        return URL of front document
                    end if
                end tell
                """
            )
        case "com.google.Chrome":
            return runAppleScript(
                """
                tell application "Google Chrome"
                    if (count of windows) > 0 then
                        return URL of active tab of front window
                    end if
                end tell
                """
            )
        default:
            return nil
        }
    }

    private func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        let scriptObject = NSAppleScript(source: script)
        let descriptor = scriptObject?.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        let output = descriptor?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let output, !output.isEmpty {
            return output
        }
        return nil
    }
}
