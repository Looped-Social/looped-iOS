import Foundation

protocol TelemetryServiceProtocol {
    func sendBatch(sessionId: UUID, events: [TelemetryEvent]) async throws -> TelemetryBatchResponse
}

final class TelemetryService: TelemetryServiceProtocol {
    private let apiClient: APIClient
    private let appVersion: String?
    private let appBuild: String?

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    func sendBatch(sessionId: UUID, events: [TelemetryEvent]) async throws -> TelemetryBatchResponse {
        guard !events.isEmpty else {
            return TelemetryBatchResponse(status: "ok", accepted: 0, dropped: 0)
        }

        let request = TelemetryBatchRequest(
            sessionId: sessionId,
            sentAtMs: TelemetryClock.nowMs,
            events: events
        )

        return try await apiClient.post(
            "/v1/telemetry/events",
            body: request,
            headers: telemetryHeaders()
        )
    }

    private func telemetryHeaders() -> [String: String] {
        var headers: [String: String] = ["X-Platform": "ios"]
        let trimmedVersion = appVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedVersion, !trimmedVersion.isEmpty {
            headers["X-Client-Version"] = trimmedVersion
        }
        let trimmedBuild = appBuild?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedBuild, !trimmedBuild.isEmpty {
            headers["X-Client-Build"] = trimmedBuild
        }
        return headers
    }
}
