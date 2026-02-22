import AppKit

@MainActor
struct NotchGeometry {
    static var hasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.safeAreaInsets.top > 0
    }

    static var notchWidth: CGFloat {
        guard hasNotch, let screen = NSScreen.main else { return 200 }
        let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
        let notchW = screen.frame.width - leftWidth - rightWidth
        return max(notchW, 180)
    }

    static var notchHeight: CGFloat {
        guard hasNotch, let screen = NSScreen.main else { return 28 }
        return screen.safeAreaInsets.top
    }

    static var collapsedSize: NSSize {
        NSSize(width: notchWidth + 20, height: notchHeight)
    }

    static var expandedSize: NSSize {
        NSSize(width: max(notchWidth + 120, 380), height: 320)
    }

    static func panelOrigin(for panelSize: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let x = screen.frame.midX - panelSize.width / 2
        if hasNotch {
            let y = screen.frame.maxY - panelSize.height
            return NSPoint(x: x, y: y)
        } else {
            let y = screen.visibleFrame.maxY - panelSize.height
            return NSPoint(x: x, y: y)
        }
    }
}
