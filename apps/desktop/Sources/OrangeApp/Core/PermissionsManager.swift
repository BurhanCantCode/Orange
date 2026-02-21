import Foundation
import AVFoundation
import ApplicationServices

final class PermissionsManager {
    func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    func checkMicrophone() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func checkScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
}
