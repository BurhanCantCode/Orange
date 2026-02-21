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

protocol PlannerClient {
    func plan(request: PlanRequest) async throws -> ActionPlan
}
