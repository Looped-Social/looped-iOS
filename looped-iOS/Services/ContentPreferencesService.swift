import Foundation

final class ContentPreferencesService: ContentPreferencesServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func getPreferences() async throws -> ContentPreferencesResponseDTO {
        try await apiClient.get("/v1/content/preferences")
    }

    func updateHideAnonymousPosts(_ hideAnonymousPosts: Bool) async throws -> ContentPreferencesResponseDTO {
        let request = ContentPreferencesUpdateRequestDTO(hideAnonymousPosts: hideAnonymousPosts)
        return try await apiClient.put("/v1/content/preferences", body: request)
    }
}

