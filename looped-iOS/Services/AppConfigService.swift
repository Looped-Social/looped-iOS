import Foundation

protocol AppConfigServiceProtocol {
    func fetch() async throws -> AppConfigDTO
}

final class AppConfigService: AppConfigServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetch() async throws -> AppConfigDTO {
        try await apiClient.get("/v1/app-config", requiresAuth: false)
    }
}

