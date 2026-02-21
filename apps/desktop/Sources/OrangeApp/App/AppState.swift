import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var state: SessionState = .idle
    @Published var transcript: String = ""
    @Published var partialTranscript: String = ""
    @Published var statusText: String = "Ready"
    @Published var actionPlan: ActionPlan?
    @Published var safetyPrompts: [SafetyPrompt] = []
    @Published var executionResult: ExecutionResult?
    @Published var plannerEvents: [PlannerStreamEvent] = []

    var sessionId: String = UUID().uuidString

    func resetSession() {
        sessionId = UUID().uuidString
        transcript = ""
        partialTranscript = ""
        statusText = "Ready"
        actionPlan = nil
        safetyPrompts = []
        executionResult = nil
        plannerEvents = []
        state = .idle
    }
}
