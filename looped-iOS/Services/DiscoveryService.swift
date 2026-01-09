import Foundation

class DiscoveryService: DiscoveryServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int

    init(apiClient: APIClient = APIClient(), defaultLimit: Int = 20) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
    }

    func searchLoops(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<LoopDTO> {
        try await search(endpoint: "/v1/loops/search", query: query, limit: limit, cursor: cursor)
    }

    func searchHashtags(query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<HashtagDTO> {
        try await search(endpoint: "/v1/hashtags/search", query: query, limit: limit, cursor: cursor)
    }

    private func search<T: Codable>(endpoint: String, query: String, limit: Int, cursor: String?) async throws -> SearchResultPage<T> {
        let encodedQuery = URLQueryEncoding.encode(query)
        var path = "\(endpoint)?query=\(encodedQuery)&limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor, !cursor.isEmpty {
            path += "&cursor=\(URLQueryEncoding.encode(cursor))"
        }

        if T.self == LoopDTO.self {
            let response: LoopSearchResponseDTO = try await apiClient.get(path)
            // swiftlint:disable:next force_cast
            return SearchResultPage(items: response.items as! [T], nextCursor: response.nextCursor)
        }

        if T.self == HashtagDTO.self {
            let response: HashtagSearchResponseDTO = try await apiClient.get(path)
            // swiftlint:disable:next force_cast
            return SearchResultPage(items: response.items as! [T], nextCursor: response.nextCursor)
        }

        throw APIError.invalidResponse
    }
}
