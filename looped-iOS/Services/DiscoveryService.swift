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
        let initial = parseRecommendedSpecializations(response)
        var majors = initial.majors
        var fields = initial.fields

        // Some backend deployments only populate one type for `type=all`. If we didn't get both,
        // opportunistically fetch the missing set(s).
        if fields.isEmpty || majors.isEmpty {
            async let majorsResponse: SpecializationsRecommendedResponseDTO? =
                majors.isEmpty
                    ? (try? apiClient.get("/v1/specializations/recommended?type=major&limit=\(resolvedLimit)"))
                    : nil

            async let fieldsResponse: SpecializationsRecommendedResponseDTO? =
                fields.isEmpty
                    ? (try? apiClient.get("/v1/specializations/recommended?type=field&limit=\(resolvedLimit)"))
                    : nil

            let (maybeMajors, maybeFields) = await (majorsResponse, fieldsResponse)

            if let maybeMajors, majors.isEmpty {
                majors = parseRecommendedSpecializations(maybeMajors).majors
            }
            if let maybeFields, fields.isEmpty {
                fields = parseRecommendedSpecializations(maybeFields).fields
            }
        }

        return RecommendedSpecializations(majors: majors, fields: fields)
    }

    private func parseRecommendedSpecializations(_ response: SpecializationsRecommendedResponseDTO) -> RecommendedSpecializations {
        let majors: [CommunitySearchResult]
        let fields: [CommunitySearchResult]

        if let responseMajors = response.majors, let responseFields = response.fields {
            majors = responseMajors.map(CommunitySearchResult.init(dto:))
            fields = responseFields.map(CommunitySearchResult.init(dto:))
        } else if let items = response.items {
            let results = items.map(CommunitySearchResult.init(dto:))
            majors = results.filter { $0.specializationType == .major }
            fields = results.filter { $0.specializationType == .field }
        } else {
            majors = (response.majors ?? []).map(CommunitySearchResult.init(dto:))
            fields = (response.fields ?? []).map(CommunitySearchResult.init(dto:))
        }

        return RecommendedSpecializations(majors: majors, fields: fields)
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
