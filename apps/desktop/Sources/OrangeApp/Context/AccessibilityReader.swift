import ApplicationServices
import Foundation

struct AccessibilityReader {
    func readSummary(maxDepth: Int = 5, maxNodes: Int = 140) -> String {
        guard AXIsProcessTrusted() else {
            return "Accessibility permission not granted"
        }

        let systemWide = AXUIElementCreateSystemWide()
        guard let focusedAppAny = copyAttribute(systemWide, attribute: kAXFocusedApplicationAttribute as CFString) else {
            return "Unable to read focused application"
        }
        let focusedApp = focusedAppAny as! AXUIElement

        let rootElement: AXUIElement
        if let focusedWindowAny = copyAttribute(focusedApp, attribute: kAXFocusedWindowAttribute as CFString) {
            rootElement = focusedWindowAny as! AXUIElement
        } else {
            rootElement = focusedApp
        }

        var lines: [String] = []
        var count = 0
        traverse(
            element: rootElement,
            depth: 0,
            maxDepth: maxDepth,
            maxNodes: maxNodes,
            lines: &lines,
            count: &count
        )

        return lines.joined(separator: "\n")
    }

    private func traverse(
        element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        maxNodes: Int,
        lines: inout [String],
        count: inout Int
    ) {
        guard depth <= maxDepth, count < maxNodes else { return }
        count += 1

        let role = (copyAttribute(element, attribute: kAXRoleAttribute as CFString) as? String) ?? "UnknownRole"
        let title = (copyAttribute(element, attribute: kAXTitleAttribute as CFString) as? String) ?? ""
        let value = stringifyValue(copyAttribute(element, attribute: kAXValueAttribute as CFString))
        let enabled = (copyAttribute(element, attribute: kAXEnabledAttribute as CFString) as? Bool) ?? false
        let description = (copyAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String) ?? ""

        lines.append(
            "[\(count)] depth=\(depth) role=\(role) title=\"\(title)\" value=\"\(value)\" enabled=\(enabled) description=\"\(description)\""
        )

        guard let rawChildren = copyAttribute(element, attribute: kAXChildrenAttribute as CFString) as? [AnyObject] else {
            return
        }
        let children = rawChildren.map { $0 as! AXUIElement }
        for child in children {
            traverse(
                element: child,
                depth: depth + 1,
                maxDepth: maxDepth,
                maxNodes: maxNodes,
                lines: &lines,
                count: &count
            )
            if count >= maxNodes { break }
        }
    }

    private func copyAttribute(_ element: AXUIElement, attribute: CFString) -> AnyObject? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        return value
    }

    private func stringifyValue(_ value: AnyObject?) -> String {
        guard let value else { return "" }

        if let text = value as? String {
            return text
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let array = value as? [AnyObject], !array.isEmpty {
            return "array(\(array.count))"
        }
        return String(describing: value)
    }
}
