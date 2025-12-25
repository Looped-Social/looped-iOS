import Foundation

class ModerationService: ModerationServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func createReport(targetType: String, targetId: Int, reason: String) async throws -> Int? {
        let request = ReportRequestDTO(targetType: targetType, targetId: targetId, reason: reason)
        let response: ReportResponseDTO = try await apiClient.post("/v1/reports", body: request)
        return response.id
    }

    func createAppeal(targetType: String, targetId: Int?, reason: String) async throws -> Int? {
        let request = AppealRequestDTO(targetType: targetType, targetId: targetId, reason: reason)
        let response: AppealResponseDTO = try await apiClient.post("/v1/appeals", body: request)
        return response.id
    }

    func fetchViolations(limit: Int, cursor: String?) async throws -> ViolationsPage {
        var endpoint = "/v1/violations?limit=\(limit)"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: ViolationsResponseDTO = try await apiClient.get(endpoint)
        let items = response.items.map { Violation(dto: $0) }
        return ViolationsPage(violations: items, nextCursor: response.nextCursor)
    }

    func fetchAppeals(status: String?) async throws -> [Appeal] {
        var endpoint = "/v1/appeals"
        if let status, !status.isEmpty {
            let encoded = status.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? status
            endpoint += "?status=\(encoded)"
        }
        let response: AppealsResponseDTO = try await apiClient.get(endpoint)
        return response.items.map { Appeal(dto: $0) }
    }
}
