import AppKit
import ApplicationServices
import Carbon
import Foundation

protocol ExecutionEngine {
    func execute(plan: ActionPlan) async -> ExecutionResult
}

final class ActionExecutor: ExecutionEngine {
    func execute(plan: ActionPlan) async -> ExecutionResult {
        var completed: [String] = []
        for action in plan.actions {
            do {
                try execute(action)
                completed.append(action.id)
                Logger.info("Executed action \(action.id): \(action.kind.rawValue)")
            } catch {
                return ExecutionResult(
                    status: .failure,
                    completedActions: completed,
                    failedActionId: action.id,
                    reason: error.localizedDescription,
                    recoverySuggestion: "Retry command"
                )
            }
        }

        return ExecutionResult(
            status: .success,
            completedActions: completed,
            failedActionId: nil,
            reason: nil,
            recoverySuggestion: nil
        )
    }

    private func execute(_ action: AgentAction) throws {
        switch action.kind {
        case .openApp:
            try openApp(action)
        case .type:
            try typeText(action.text)
        case .keyCombo:
            try pressKeyCombo(action.keyCombo)
        case .runAppleScript:
            try runAppleScript(action.text ?? action.target ?? "")
        case .wait:
            Thread.sleep(forTimeInterval: max(0.05, Double(action.timeoutMs) / 1000.0))
        case .click:
            try clickTarget(action.target)
        case .scroll:
            try scrollTarget(action.target)
        case .selectMenuItem:
            try selectMenuItem(action.target)
        }
    }

    private func openApp(_ action: AgentAction) throws {
        if let bundleID = action.appBundleId, !bundleID.isEmpty {
            guard let resolvedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                throw ActionExecutionError.invalidActionPayload("Could not resolve bundle id: \(bundleID)")
            }
            let semaphore = DispatchSemaphore(value: 0)
            var openError: Error?
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(at: resolvedURL, configuration: configuration) { _, error in
                openError = error
                semaphore.signal()
            }

            if semaphore.wait(timeout: .now() + 5) == .timedOut {
                throw ActionExecutionError.invalidActionPayload("Timed out launching app bundle id \(bundleID)")
            }
            if let openError {
                throw ActionExecutionError.invalidActionPayload("Launch failed: \(openError.localizedDescription)")
            }
        } else {
            guard let appName = action.target, !appName.isEmpty else {
                throw ActionExecutionError.invalidActionPayload("Missing app name for open_app")
            }
            let escaped = escapeAppleScriptText(appName)
            try runAppleScript(
                """
                tell application "\(escaped)"
                    activate
                end tell
                """
            )
        }
    }

    private func typeText(_ text: String?) throws {
        guard let text, !text.isEmpty else {
            throw ActionExecutionError.invalidActionPayload("Missing text for type action")
        }
        let escaped = escapeAppleScriptText(text)
        try runAppleScript(
            """
            tell application "System Events"
                keystroke "\(escaped)"
            end tell
            """
        )
    }

    private func pressKeyCombo(_ combo: String?) throws {
        guard let combo, !combo.isEmpty else {
            throw ActionExecutionError.invalidActionPayload("Missing key_combo value")
        }
        let parts = combo
            .lowercased()
            .split(separator: "+")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let key = parts.last else {
            throw ActionExecutionError.invalidActionPayload("Invalid key_combo format: \(combo)")
        }

        var flags: CGEventFlags = []
        for modifier in parts.dropLast() {
            switch modifier {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "alt", "option": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            default:
                throw ActionExecutionError.invalidActionPayload("Unsupported modifier: \(modifier)")
            }
        }

        guard let keyCode = keyCode(for: key) else {
            throw ActionExecutionError.invalidActionPayload("Unsupported key: \(key)")
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw ActionExecutionError.systemEventCreationFailed
        }

        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func runAppleScript(_ script: String) throws {
        guard !script.isEmpty else {
            throw ActionExecutionError.invalidActionPayload("AppleScript payload is empty")
        }
        var error: NSDictionary?
        let scriptObject = NSAppleScript(source: script)
        _ = scriptObject?.executeAndReturnError(&error)
        if let error {
            throw ActionExecutionError.appleScriptFailed(error.description)
        }
    }

    private func clickTarget(_ target: String?) throws {
        guard AXIsProcessTrusted() else {
            throw ActionExecutionError.permissions("Accessibility permission is required for click actions")
        }
        guard let target, !target.isEmpty else {
            throw ActionExecutionError.invalidActionPayload("Missing target for click action")
        }

        let systemWide = AXUIElementCreateSystemWide()
        guard let focusedAppAny = copyAttribute(systemWide, attribute: kAXFocusedApplicationAttribute as CFString) else {
            throw ActionExecutionError.elementNotFound("Focused app unavailable")
        }
        let focusedApp = focusedAppAny as! AXUIElement

        let rootElement: AXUIElement
        if let windowAny = copyAttribute(focusedApp, attribute: kAXFocusedWindowAttribute as CFString) {
            rootElement = windowAny as! AXUIElement
        } else {
            rootElement = focusedApp
        }

        guard let element = findElement(containing: target, in: rootElement, maxDepth: 8, maxNodes: 500) else {
            throw ActionExecutionError.elementNotFound("Could not find element matching target '\(target)'")
        }

        let pressResult = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if pressResult != .success {
            throw ActionExecutionError.elementInteractionFailed("Press action failed with AXError \(pressResult.rawValue)")
        }
    }

    private func scrollTarget(_ target: String?) throws {
        let normalized = (target ?? "down").lowercased()
        let isUp = normalized.contains("up")
        let isLeft = normalized.contains("left")
        let isRight = normalized.contains("right")
        let magnitude = extractMagnitude(from: normalized, defaultValue: 8)

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw ActionExecutionError.systemEventCreationFailed
        }

        let vertical: Int32
        if isUp {
            vertical = Int32(magnitude)
        } else {
            vertical = -Int32(magnitude)
        }

        let horizontal: Int32
        if isLeft {
            horizontal = Int32(magnitude)
        } else if isRight {
            horizontal = -Int32(magnitude)
        } else {
            horizontal = 0
        }

        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .line,
            wheelCount: 2,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        ) else {
            throw ActionExecutionError.systemEventCreationFailed
        }
        event.post(tap: .cghidEventTap)
    }

    private func selectMenuItem(_ target: String?) throws {
        guard let target, !target.isEmpty else {
            throw ActionExecutionError.invalidActionPayload("Missing target for select_menu_item action")
        }
        guard let appName = NSWorkspace.shared.frontmostApplication?.localizedName, !appName.isEmpty else {
            throw ActionExecutionError.invalidActionPayload("Unable to detect frontmost app for menu selection")
        }

        let components = splitMenuPath(target)
        guard components.count >= 2 else {
            throw ActionExecutionError.invalidActionPayload(
                "Menu path must be like 'File > New Window' (received: \(target))"
            )
        }

        let menu = escapeAppleScriptText(components[0])
        let item = escapeAppleScriptText(components[1])
        let app = escapeAppleScriptText(appName)

        try runAppleScript(
            """
            tell application "System Events"
                tell process "\(app)"
                    click menu item "\(item)" of menu "\(menu)" of menu bar 1
                end tell
            end tell
            """
        )
    }

    private func keyCode(for key: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            "a": CGKeyCode(kVK_ANSI_A),
            "b": CGKeyCode(kVK_ANSI_B),
            "c": CGKeyCode(kVK_ANSI_C),
            "d": CGKeyCode(kVK_ANSI_D),
            "e": CGKeyCode(kVK_ANSI_E),
            "f": CGKeyCode(kVK_ANSI_F),
            "g": CGKeyCode(kVK_ANSI_G),
            "h": CGKeyCode(kVK_ANSI_H),
            "i": CGKeyCode(kVK_ANSI_I),
            "j": CGKeyCode(kVK_ANSI_J),
            "k": CGKeyCode(kVK_ANSI_K),
            "l": CGKeyCode(kVK_ANSI_L),
            "m": CGKeyCode(kVK_ANSI_M),
            "n": CGKeyCode(kVK_ANSI_N),
            "o": CGKeyCode(kVK_ANSI_O),
            "p": CGKeyCode(kVK_ANSI_P),
            "q": CGKeyCode(kVK_ANSI_Q),
            "r": CGKeyCode(kVK_ANSI_R),
            "s": CGKeyCode(kVK_ANSI_S),
            "t": CGKeyCode(kVK_ANSI_T),
            "u": CGKeyCode(kVK_ANSI_U),
            "v": CGKeyCode(kVK_ANSI_V),
            "w": CGKeyCode(kVK_ANSI_W),
            "x": CGKeyCode(kVK_ANSI_X),
            "y": CGKeyCode(kVK_ANSI_Y),
            "z": CGKeyCode(kVK_ANSI_Z),
            "0": CGKeyCode(kVK_ANSI_0),
            "1": CGKeyCode(kVK_ANSI_1),
            "2": CGKeyCode(kVK_ANSI_2),
            "3": CGKeyCode(kVK_ANSI_3),
            "4": CGKeyCode(kVK_ANSI_4),
            "5": CGKeyCode(kVK_ANSI_5),
            "6": CGKeyCode(kVK_ANSI_6),
            "7": CGKeyCode(kVK_ANSI_7),
            "8": CGKeyCode(kVK_ANSI_8),
            "9": CGKeyCode(kVK_ANSI_9),
            "enter": CGKeyCode(kVK_Return),
            "return": CGKeyCode(kVK_Return),
            "space": CGKeyCode(kVK_Space),
            "tab": CGKeyCode(kVK_Tab),
            "escape": CGKeyCode(kVK_Escape),
            "esc": CGKeyCode(kVK_Escape),
            "up": CGKeyCode(kVK_UpArrow),
            "down": CGKeyCode(kVK_DownArrow),
            "left": CGKeyCode(kVK_LeftArrow),
            "right": CGKeyCode(kVK_RightArrow),
        ]
        return map[key]
    }

    private func escapeAppleScriptText(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func splitMenuPath(_ target: String) -> [String] {
        let delimiters = [" > ", ">", "/", "->"]
        var working = target
        for delimiter in delimiters {
            working = working.replacingOccurrences(of: delimiter, with: "|")
        }
        return working
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func extractMagnitude(from text: String, defaultValue: Int) -> Int {
        let digits = text.filter(\.isNumber)
        if let value = Int(digits), value > 0 {
            return min(value, 50)
        }
        return defaultValue
    }

    private func copyAttribute(_ element: AXUIElement, attribute: CFString) -> AnyObject? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        return value
    }

    private func findElement(
        containing target: String,
        in root: AXUIElement,
        maxDepth: Int,
        maxNodes: Int
    ) -> AXUIElement? {
        let needle = target.lowercased()
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var visited = 0

        while !queue.isEmpty, visited < maxNodes {
            let (element, depth) = queue.removeFirst()
            visited += 1

            if elementMatches(element, needle: needle) {
                return element
            }

            guard depth < maxDepth else { continue }
            if let children = copyAttribute(element, attribute: kAXChildrenAttribute as CFString) as? [AnyObject] {
                queue.append(contentsOf: children.map { ($0 as! AXUIElement, depth + 1) })
            }
        }
        return nil
    }

    private func elementMatches(_ element: AXUIElement, needle: String) -> Bool {
        let fields: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXValueAttribute as CFString,
            kAXRoleAttribute as CFString,
            kAXRoleDescriptionAttribute as CFString,
        ]
        for field in fields {
            if let value = copyAttribute(element, attribute: field), String(describing: value).lowercased().contains(needle) {
                return true
            }
        }
        return false
    }
}

private enum ActionExecutionError: LocalizedError {
    case unsupportedAction(String)
    case invalidActionPayload(String)
    case appleScriptFailed(String)
    case systemEventCreationFailed
    case permissions(String)
    case elementNotFound(String)
    case elementInteractionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedAction(kind):
            return "Unsupported action kind: \(kind)"
        case let .invalidActionPayload(message):
            return "Invalid action payload: \(message)"
        case let .appleScriptFailed(message):
            return "AppleScript execution failed: \(message)"
        case .systemEventCreationFailed:
            return "Could not create keyboard event."
        case let .permissions(message):
            return "Permission error: \(message)"
        case let .elementNotFound(message):
            return "Element not found: \(message)"
        case let .elementInteractionFailed(message):
            return "Element interaction failed: \(message)"
        }
    }
}
