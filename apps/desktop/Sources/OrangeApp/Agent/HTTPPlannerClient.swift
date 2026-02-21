import Foundation

final class HTTPPlannerClient: PlannerClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://127.0.0.1:7789")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func plan(request: PlanRequest) async throws -> ActionPlan {
        let endpoint = baseURL.appendingPathComponent("/v1/plan")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ActionPlan.self, from: data)
    }

    func verify(
        sessionId: String,
        plan: ActionPlan,
        executionStatus: ExecutionStatus,
        reason: String?,
        beforeContext: String?,
        afterContext: String?
    ) async throws -> VerifyResponse {
        let payload = VerifyRequestPayload(
            schemaVersion: 1,
            sessionId: sessionId,
            actionPlan: plan,
            executionResult: executionStatus,
            reason: reason,
            beforeContext: beforeContext,
            afterContext: afterContext
        )

        let endpoint = baseURL.appendingPathComponent("/v1/verify")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(VerifyResponse.self, from: data)
    }

    func streamEvents(sessionId: String) -> AsyncThrowingStream<PlannerStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let endpoint = baseURL.appendingPathComponent("/v1/events/\(sessionId)")
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "GET"
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200 ... 299).contains(httpResponse.statusCode) else {
                        throw URLError(.badServerResponse)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                        guard let data = payload.data(using: .utf8) else { continue }
                        if let event = try? JSONDecoder().decode(PlannerStreamEvent.self, from: data) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

private struct VerifyRequestPayload: Codable {
    let schemaVersion: Int
    let sessionId: String
    let actionPlan: ActionPlan
    let executionResult: ExecutionStatus
    let reason: String?
    let beforeContext: String?
    let afterContext: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sessionId = "session_id"
        case actionPlan = "action_plan"
        case executionResult = "execution_result"
        case reason
        case beforeContext = "before_context"
        case afterContext = "after_context"
    }
}
