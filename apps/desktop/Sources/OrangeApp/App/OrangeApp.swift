import SwiftUI

@main
struct OrangeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var appState = AppState()

    private let sessionManager: SessionManager
    private let sidecarManager = PythonSidecarManager()
    private let hotkeyManager = HotkeyManager()

    init() {
        let stt = AppleSpeechRecognizer()
        let context = LocalContextProvider()
        let planner = HTTPPlannerClient()
        let executor = ActionExecutor()
        let safety = DefaultSafetyPolicy()

        self.sessionManager = SessionManager(
            sttService: stt,
            contextProvider: context,
            plannerClient: planner,
            executionEngine: executor,
            safetyPolicy: safety
        )
    }

    var body: some Scene {
        WindowGroup("Orange") {
            OverlayView(
                appState: appState,
                onStart: {
                    sessionManager.beginRecording(state: appState)
                },
                onStop: {
                    Task { await sessionManager.stopRecordingAndPlan(state: appState) }
                },
                onConfirm: {
                    Task { await sessionManager.confirmAndExecute(state: appState) }
                },
                onCancel: {
                    sessionManager.cancel(state: appState)
                }
            )
            .onAppear {
                sidecarManager.startIfNeeded()
                hotkeyManager.register(
                    onPress: { sessionManager.beginRecording(state: appState) },
                    onRelease: { Task { await sessionManager.stopRecordingAndPlan(state: appState) } }
                )
            }
            .onDisappear {
                sidecarManager.stop()
            }
        }
        .windowResizability(.contentSize)
    }
}
