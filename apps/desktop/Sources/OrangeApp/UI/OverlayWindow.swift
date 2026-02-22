import AppKit
import SwiftUI

enum OverlayMode {
    case collapsed
    case expanded
}

@MainActor
final class OverlayWindow {
    static let shared = OverlayWindow()

    private var panel: NSPanel?
    private(set) var mode: OverlayMode = .collapsed

    private init() {}

    func attach<Content: View>(rootView: Content) {
        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(rootView: rootView)
        self.panel = panel
    }

    func show() {
        guard let panel else { return }
        setMode(.collapsed, animated: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func setMode(_ newMode: OverlayMode, animated: Bool = true) {
        mode = newMode
        guard let panel else { return }

        let targetSize: NSSize
        switch newMode {
        case .collapsed:
            targetSize = NotchGeometry.collapsedSize
            panel.hasShadow = false
        case .expanded:
            targetSize = NotchGeometry.expandedSize
            panel.hasShadow = true
        }

        let origin = NotchGeometry.panelOrigin(for: targetSize)
        let targetFrame = NSRect(origin: origin, size: targetSize)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }

    private func makePanel() -> NSPanel {
        let size = NotchGeometry.collapsedSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.ignoresMouseEvents = false

        let origin = NotchGeometry.panelOrigin(for: size)
        panel.setFrameOrigin(origin)

        return panel
    }
}
