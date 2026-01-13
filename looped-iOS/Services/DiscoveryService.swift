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

    func fetchRecommendedSpecializations(limit: Int) async throws -> RecommendedSpecializations {
        let resolvedLimit = min(max(limit, 1), 50)
        let endpoint = "/v1/specializations/recommended?type=all&limit=\(resolvedLimit)"
        let response: SpecializationsRecommendedResponseDTO = try await apiClient.get(endpoint)
        let majors: [CommunitySearchResult]
        let departments: [CommunitySearchResult]

        if let responseMajors = response.majors, let responseDepartments = response.departments {
            majors = responseMajors.map(CommunitySearchResult.init(dto:))
            departments = responseDepartments.map(CommunitySearchResult.init(dto:))
        } else if let items = response.items {
            let results = items.map(CommunitySearchResult.init(dto:))
            majors = results.filter { $0.specializationType == .major }
            departments = results.filter { $0.specializationType == .department }
        } else {
            majors = (response.majors ?? []).map(CommunitySearchResult.init(dto:))
            departments = (response.departments ?? []).map(CommunitySearchResult.init(dto:))
        }
        return RecommendedSpecializations(majors: majors, departments: departments)
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
