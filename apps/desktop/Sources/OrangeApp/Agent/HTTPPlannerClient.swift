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
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let detail = parseServerDetail(from: data)
            throw PlannerServiceError.server(
                message: detail?.message ?? "Planning request failed",
                errorCode: detail?.errorCode
            )
        }

        return try JSONDecoder().decode(ActionPlan.self, from: data)
    }

    func simulate(request: PlanSimulationRequest) async throws -> PlanSimulationResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/plan/simulate")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let detail = parseServerDetail(from: data)
            throw PlannerServiceError.server(
                message: detail?.message ?? "Plan simulation failed",
                errorCode: detail?.errorCode
            )
        }

        return try JSONDecoder().decode(PlanSimulationResponse.self, from: data)
    }

    func models() async throws -> ModelsResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/models")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ModelsResponse.self, from: data)
    }

    func providerStatus() async throws -> ProviderStatusResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/provider/status")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let detail = parseServerDetail(from: data)
            throw PlannerServiceError.server(
                message: detail?.message ?? "Failed to fetch provider status",
                errorCode: detail?.errorCode
            )
        }
        return try JSONDecoder().decode(ProviderStatusResponse.self, from: data)
    }

    func validateProvider(request payload: ProviderValidateRequest) async throws -> ProviderValidateResponse {
        let endpoint = baseURL.appendingPathComponent("/v1/provider/validate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let detail = parseServerDetail(from: data)
            throw PlannerServiceError.server(
                message: detail?.message ?? "Provider validation failed",
                errorCode: detail?.errorCode
            )
        }
        return try JSONDecoder().decode(ProviderValidateResponse.self, from: data)
    }

    func telemetry(event: SessionTelemetryEvent) async {
        do {
            let endpoint = baseURL.appendingPathComponent("/v1/telemetry")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(event)
            _ = try await session.data(for: request)
        } catch {
            Logger.error("Telemetry upload failed: \(error.localizedDescription)")
        }
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
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let detail = parseServerDetail(from: data)
            throw PlannerServiceError.server(
                message: detail?.message ?? "Verification request failed",
                errorCode: detail?.errorCode
            )
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

private struct ServerErrorDetail {
    let message: String
    let errorCode: String?
}

private func parseServerDetail(from data: Data) -> ServerErrorDetail? {
    guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    if let detail = payload["detail"] as? [String: Any],
       let message = detail["message"] as? String {
        return ServerErrorDetail(message: message, errorCode: detail["error_code"] as? String)
    }
    if let detail = payload["detail"] as? String {
        return ServerErrorDetail(message: detail, errorCode: nil)
    }
    return nil
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
