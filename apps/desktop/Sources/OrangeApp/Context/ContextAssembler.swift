import Foundation

struct ContextAssembler {
    let appDetector = AppDetector()
    let reader = AccessibilityReader()
    let capture = ScreenCaptureService()

    func assemble() -> ScreenContext {
        ScreenContext(
            screenshotBase64: capture.captureBase64JPEG(),
            axTreeSummary: reader.readSummary(),
            app: appDetector.currentApp()
        )
    }
}
