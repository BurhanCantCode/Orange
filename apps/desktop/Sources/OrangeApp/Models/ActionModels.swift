import Foundation

enum ActionKind: String, Codable, CaseIterable {
    case click
    case type
    case keyCombo = "key_combo"
    case scroll
    case openApp = "open_app"
    case runAppleScript = "run_applescript"
    case selectMenuItem = "select_menu_item"
    case wait
}

struct AgentAction: Codable, Hashable, Identifiable {
    let id: String
    let kind: ActionKind
    let target: String?
    let text: String?
    let keyCombo: String?
    let appBundleId: String?
    let timeoutMs: Int
    let destructive: Bool
    let expectedOutcome: String?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case target
        case text
        case keyCombo = "key_combo"
        case appBundleId = "app_bundle_id"
        case timeoutMs = "timeout_ms"
        case destructive
        case expectedOutcome = "expected_outcome"
    }
}

struct ActionPlan: Codable {
    let schemaVersion: Int
    let sessionId: String
    let actions: [AgentAction]
    let confidence: Double
    let riskLevel: String
    let requiresConfirmation: Bool
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sessionId = "session_id"
        case actions
        case confidence
        case riskLevel = "risk_level"
        case requiresConfirmation = "requires_confirmation"
        case summary
    }
}

enum ExecutionStatus: String, Codable {
    case success
    case failure
    case partial
}

struct ExecutionResult: Codable {
    let status: ExecutionStatus
    let completedActions: [String]
    let failedActionId: String?
    let reason: String?
    let recoverySuggestion: String?

    enum CodingKeys: String, CodingKey {
        case status
        case completedActions = "completed_actions"
        case failedActionId = "failed_action_id"
        case reason
        case recoverySuggestion = "recovery_suggestion"
    }
}
