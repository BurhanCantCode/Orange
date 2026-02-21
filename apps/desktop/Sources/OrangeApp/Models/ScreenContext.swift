import Foundation

struct AppMetadata: Codable {
    let name: String?
    let bundleId: String?
    let windowTitle: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case name
        case bundleId = "bundle_id"
        case windowTitle = "window_title"
        case url
    }
}

struct ScreenContext: Codable {
    let screenshotBase64: String?
    let axTreeSummary: String?
    let app: AppMetadata

    enum CodingKeys: String, CodingKey {
        case screenshotBase64 = "screenshot_base64"
        case axTreeSummary = "ax_tree_summary"
        case app
    }
}
