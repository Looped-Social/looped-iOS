import Foundation

final class BlockService: BlockServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchBlockedUsers(limit: Int, cursor: String?) async throws -> BlockedUsersPage {
        var endpoint = "/v1/users/blocked?limit=\(limit)"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: BlockedUsersResponseDTO = try await apiClient.get(endpoint)
        let users = response.items.map { BlockedUser(dto: $0) }
        return BlockedUsersPage(users: users, nextCursor: response.nextCursor)
    }

    func blockUser(userId: Int) async throws -> BlockActionResult {
        let response: BlockActionResponseDTO = try await apiClient.post(
            "/v1/users/\(userId)/block",
            body: EmptyBody()
        )
        return BlockActionResult(userId: response.userId, blocked: response.blocked)
    }

    func unblockUser(userId: Int) async throws -> BlockActionResult {
        let response: BlockActionResponseDTO = try await apiClient.delete(
            "/v1/users/\(userId)/block",
            expecting: BlockActionResponseDTO.self
        )
        return BlockActionResult(userId: response.userId, blocked: response.blocked)
    }
}

private struct EmptyBody: Codable {}
