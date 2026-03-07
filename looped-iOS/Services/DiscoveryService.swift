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
        var fields = initial.fields

        // Some backend deployments only populate one type for `type=all`. We only support fields.
        let needsFields = fields.isEmpty
        if needsFields {
            async let fieldsResponse: SpecializationsRecommendedResponseDTO? =
                try? apiClient.get("/v1/specializations/recommended?type=field&limit=\(resolvedLimit)")
            let maybeFields = await fieldsResponse
            if let maybeFields {
                fields = parseRecommendedSpecializations(maybeFields).fields
            }
        }

        return RecommendedSpecializations(majors: [], fields: fields)
    }

    func browseSpecializations(
        type: CommunitySpecializationType,
        limit: Int,
        cursor: String?
    ) async throws -> SearchResultPage<CommunitySearchResult> {
        let resolvedType: CommunitySpecializationType
        switch type {
        case .field, .major:
            resolvedType = .field
        case .unknown:
            throw APIError.invalidResponse
        }

        let resolvedLimit = min(max(limit, 1), 100)
        var endpoint = "/v1/specializations/browse?type=\(resolvedType.rawValue)&limit=\(resolvedLimit)"
        if let cursor, !cursor.isEmpty {
            endpoint += "&cursor=\(URLQueryEncoding.encode(cursor))"
        }

        let response: CommunitySearchResponseDTO = try await apiClient.get(endpoint)
        return SearchResultPage(
            items: response.items.map(CommunitySearchResult.init(dto:)),
            nextCursor: response.nextCursor
        )
    }

    func fetchMajorsIndex() async throws -> [SpecializationIndexItem] {
        []
    }

    func fetchFieldsIndex() async throws -> [SpecializationIndexItem] {
        let response: SpecializationIndexResponseDTO = try await apiClient.get("/v1/fields")
        return response.items.map(SpecializationIndexItem.init(dto:))
    }

    private func parseRecommendedSpecializations(_ response: SpecializationsRecommendedResponseDTO) -> RecommendedSpecializations {
        let fields: [CommunitySearchResult]

        if let responseFields = response.fields {
            fields = responseFields
                .map(CommunitySearchResult.init(dto:))
                .filter { $0.specializationType == .field }
        } else if let items = response.items {
            let results = items.map(CommunitySearchResult.init(dto:))
            fields = results.filter { $0.specializationType == .field }
        } else {
            fields = (response.fields ?? [])
                .map(CommunitySearchResult.init(dto:))
                .filter { $0.specializationType == .field }
        }

        return RecommendedSpecializations(majors: [], fields: fields)
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
