import AppKit
import Foundation

final class HotkeyManager {
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?

    private let targetKeyCode: UInt16 = 31 // O

    func register(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) {
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if self.matchesHotkey(event) {
                onPress()
            }
        }

        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self else { return }
            if self.matchesHotkey(event) {
                onRelease()
            }
        }
    }

    private func matchesHotkey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == targetKeyCode && modifiers.contains([.command, .shift])
    }

    deinit {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
        }
    }
}
