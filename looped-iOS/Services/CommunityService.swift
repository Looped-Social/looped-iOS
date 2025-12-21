import Foundation

class CommunityService: CommunityServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int

    init(apiClient: APIClient = APIClient(), defaultLimit: Int = 20) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
    }

    func fetchFollowedCommunities(limit: Int, cursor: String?) async throws -> CommunityPage {
        var endpoint = "/v1/me/followed/communities?limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: CommunityFollowResponseDTO = try await apiClient.get(endpoint)
        let items = response.items.map(CommunitySummary.init(dto:))
        return CommunityPage(items: items, nextCursor: response.nextCursor)
    }

    func searchCommunities(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<CommunitySearchResult> {
        var endpoint = "/v1/communities/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: CommunitySearchResponseDTO = try await apiClient.get(endpoint)
        let items = response.items.map(CommunitySearchResult.init(dto:))
        return SearchResultPage(items: items, nextCursor: response.nextCursor)
    }

    func followCommunity(id: Int) async throws {
        let _: EmptyResponse = try await apiClient.post("/v1/communities/\(id)/follow", body: EmptyBody())
    }

    func unfollowCommunity(id: Int) async throws {
        try await apiClient.delete("/v1/communities/\(id)/follow")
    }
}

private struct EmptyBody: Codable {}
