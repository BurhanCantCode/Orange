import AppKit
import Carbon
import Foundation

final class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var onPress: (() -> Void)?
    private var onRelease: (() -> Void)?
    private var isPressed = false

    private let targetKeyCode: UInt16 = UInt16(kVK_F8)
    private let targetModifiers: UInt32 = 0
    private let hotKeySignature: OSType = 0x4F524E47 // ORNG

    func register(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) {
        self.onPress = onPress
        self.onRelease = onRelease
        unregisterFallbackMonitors()

        if registerCarbonHotkey() {
            Logger.info("Registered Carbon hotkey (f8)")
            return
        }

        Logger.info("Falling back to global event monitors for hotkey registration")
        registerFallbackMonitors(onPress: onPress, onRelease: onRelease)
    }

    private func registerCarbonHotkey() -> Bool {
        unregisterCarbonHotkey()

        var eventTypeSpecs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(noErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotkeyEvent(event)
            },
            2,
            &eventTypeSpecs,
            userData,
            &eventHandler
        )
        guard handlerStatus == noErr else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(targetKeyCode),
            targetModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            unregisterCarbonHotkey()
            return false
        }
        return true
    }

    private func handleHotkeyEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == hotKeySignature else {
            return OSStatus(noErr)
        }

        let kind = GetEventKind(event)
        if kind == UInt32(kEventHotKeyPressed), !isPressed {
            isPressed = true
            onPress?()
        } else if kind == UInt32(kEventHotKeyReleased), isPressed {
            isPressed = false
            onRelease?()
        }
        return OSStatus(noErr)
    }

    private func registerFallbackMonitors(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) {
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if self.matchesHotkey(event) {
                self.isPressed = true
                onPress()
            }
        }

        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self else { return }
            if self.matchesHotkey(event) {
                self.isPressed = false
                onRelease()
            }
        }
    }

    private func matchesHotkey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let onlyFunctionModifier = modifiers.subtracting([.function]).isEmpty
        return event.keyCode == targetKeyCode && onlyFunctionModifier
    }

    private func unregisterCarbonHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        isPressed = false
    }

    private func unregisterFallbackMonitors() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
            self.keyUpMonitor = nil
        }
        isPressed = false
    }

    deinit {
        unregisterFallbackMonitors()
        unregisterCarbonHotkey()
    }
}
