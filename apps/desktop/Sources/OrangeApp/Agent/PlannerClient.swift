import Foundation

struct PlanRequest: Codable {
    let schemaVersion: Int
    let sessionId: String
    let transcript: String
    let screenshotBase64: String?
    let axTreeSummary: String?
    let app: AppMetadata
    let preferences: PlannerPreferences?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sessionId = "session_id"
        case transcript
        case screenshotBase64 = "screenshot_base64"
        case axTreeSummary = "ax_tree_summary"
        case app
        case preferences
    }
}

struct PlannerPreferences: Codable {
    let preferredModel: String?
    let locale: String?
    let lowLatency: Bool

    enum CodingKeys: String, CodingKey {
        case preferredModel = "preferred_model"
        case locale
        case lowLatency = "low_latency"
    }
}

struct PlannerStreamEvent: Codable, Identifiable {
    let sessionId: String
    let event: String
    let message: String
    let progress: Int?

    var id: String { "\(sessionId)-\(event)-\(message)-\(progress ?? -1)" }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case event
        case message
        case progress
    }
}

struct VerifyResponse: Codable {
    let schemaVersion: Int
    let sessionId: String
    let status: String
    let confidence: Double
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sessionId = "session_id"
        case status
        case confidence
        case reason
    }
}

protocol PlannerClient {
    func plan(request: PlanRequest) async throws -> ActionPlan
    func verify(
        sessionId: String,
        plan: ActionPlan,
        executionStatus: ExecutionStatus,
        reason: String?,
        beforeContext: String?,
        afterContext: String?
    ) async throws -> VerifyResponse
    func streamEvents(sessionId: String) -> AsyncThrowingStream<PlannerStreamEvent, Error>
}
