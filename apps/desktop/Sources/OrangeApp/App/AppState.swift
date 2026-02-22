import Foundation
import SwiftUI

enum OnboardingGate: String {
    case needsAPIKey
    case needsPermissions
    case ready
}

@MainActor
final class AppState: ObservableObject {
    @Published var state: SessionState = .idle
    @Published var transcript: String = ""
    @Published var partialTranscript: String = ""
    @Published var statusText: String = "Ready"
    @Published var actionPlan: ActionPlan?
    @Published var safetyPrompts: [SafetyPrompt] = []
    @Published var safetyAuditTrail: [SafetyDecisionRecord] = []
    @Published var executionResult: ExecutionResult?
    @Published var plannerEvents: [PlannerStreamEvent] = []
    @Published var onboardingGate: OnboardingGate = .needsAPIKey
    @Published var sidecarHealthy: Bool = false
    @Published var diagnosticsText: String = ""
    @Published var overlayExpanded: Bool = false

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

    var isReadyForCommands: Bool {
        onboardingGate == .ready && sidecarHealthy
    }
}
