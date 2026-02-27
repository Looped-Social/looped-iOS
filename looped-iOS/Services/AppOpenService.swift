import Foundation

final class AppOpenService: AppOpenServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func reportOpen(
        openedAt: Date?,
        activeCommunityId: Int?,
        seenCommunityIds: [Int]?
    ) async throws -> AppOpenResponseDTO {
        let openedAtString = openedAt.map { Self.iso8601WithFractional.string(from: $0) }
        let request = AppOpenRequestDTO(
            openedAt: openedAtString,
            activeCommunityId: activeCommunityId,
            seenCommunityIds: seenCommunityIds
        )
        let response: AppOpenResponseDTO = try await apiClient.post("/v1/app/open", body: request)
        return response
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

