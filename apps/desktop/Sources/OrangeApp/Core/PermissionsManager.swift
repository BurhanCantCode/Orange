import Foundation
import AVFoundation
import ApplicationServices
import AppKit

final class PermissionsManager {
    struct Status {
        let accessibility: Bool
        let microphone: Bool
        let screenRecording: Bool

        var allGranted: Bool {
            accessibility && microphone && screenRecording
        }
    }

    func currentStatus() -> Status {
        Status(
            accessibility: checkAccessibility(),
            microphone: checkMicrophone(),
            screenRecording: checkScreenRecording()
        )
    }

    func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func checkMicrophone() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func checkScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func promptAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func openSettingsAccessibility() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openSettingsMicrophone() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func openSettingsScreenRecording() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func openSettings(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
