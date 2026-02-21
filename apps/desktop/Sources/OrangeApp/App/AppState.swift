import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var state: SessionState = .idle
    @Published var transcript: String = ""
    @Published var statusText: String = "Ready"
    @Published var actionPlan: ActionPlan?
    @Published var safetyPrompts: [SafetyPrompt] = []
    @Published var executionResult: ExecutionResult?

    var sessionId: String = UUID().uuidString

    func resetSession() {
        sessionId = UUID().uuidString
        transcript = ""
        statusText = "Ready"
        actionPlan = nil
        safetyPrompts = []
        executionResult = nil
        state = .idle
    }
}
