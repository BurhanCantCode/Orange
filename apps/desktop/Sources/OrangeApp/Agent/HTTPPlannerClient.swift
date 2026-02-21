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
}
