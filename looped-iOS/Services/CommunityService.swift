import Foundation

class CommunityService: CommunityServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int

    init(apiClient: APIClient = APIClient(), defaultLimit: Int = 20) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
    }

    func fetchFollowedCommunities(
        limit: Int,
        cursor: String?,
        order: CommunityFollowOrder = .relevant
    ) async throws -> CommunityPage {
        var endpoint = "/v1/me/followed/communities?limit=\(limit > 0 ? limit : defaultLimit)&order=\(order.rawValue)"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: CommunityFollowResponseDTO = try await apiClient.get(endpoint)
        let items = response.items.map(CommunitySummary.init(dto:))
        return CommunityPage(items: items, nextCursor: response.nextCursor)
    }

    func fetchRecommendedCommunities(kind: CommunitySearchKind?, limit: Int) async throws -> [CommunitySearchResult] {
        var endpoint = "/v1/communities/recommended?limit=\(limit > 0 ? limit : defaultLimit)"
        if let kindValue = kind?.queryValue {
            endpoint += "&kind=\(kindValue)"
        }
        let response: CommunityRecommendedResponseDTO = try await apiClient.get(endpoint)
        return response.items.map(CommunitySearchResult.init(dto:))
    }

    func fetchCommunityDetails(communityId: Int) async throws -> CommunityProfileData {
        let endpoint = "/v1/communities/\(communityId)"
        let response: CommunityDetailsDTO = try await apiClient.get(endpoint)
        return CommunityProfileData(details: response)
    }

    func fetchCommunityDomains(communityId: Int) async throws -> [String] {
        let response: CommunityDomainsResponseDTO = try await apiClient.get("/v1/communities/\(communityId)/domains")
        return response.items
    }

    func fetchJoinedSpecializations(type: CommunitySpecializationType?) async throws -> [DisplayCommunity] {
        let filterType = type ?? .unknown
        let typeQuery: String = {
            switch filterType {
            case .major:
                return "major"
            case .field:
                return "field"
            case .unknown:
                return "all"
            }
        }()

        var aggregated: [DisplayCommunity] = []
        var cursor: String?
        let pageLimit = 200
        let maxTotal = 500

        while true {
            var endpoint = "/v1/me/joined/specializations?type=\(typeQuery)&limit=\(pageLimit)"
            if let cursor, !cursor.isEmpty {
                let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
                endpoint += "&cursor=\(encoded)"
            }
            let response: JoinedSpecializationsResponseDTO = try await apiClient.get(endpoint)
            aggregated.append(
                contentsOf: response.items.map { item in
                    DisplayCommunity(
                        id: item.id,
                        name: item.name,
                        shortName: item.shortName,
                        kind: .specialization,
                        specializationType: CommunitySpecializationType(rawValue: item.specializationType ?? "") ?? .unknown
                    )
                }
            )
            cursor = response.nextCursor
            if cursor == nil || aggregated.count >= maxTotal {
                break
            }
        }

        let filtered = aggregated.filter { item in
            let type = item.specializationType ?? .unknown
            guard type != .unknown else { return false }
            if filterType != .unknown, type != filterType { return false }
            return true
        }

        return filtered.sorted { lhs, rhs in
            let leftType = lhs.specializationType ?? .unknown
            let rightType = rhs.specializationType ?? .unknown
            if leftType != rightType {
                // Keep majors before fields for pickers.
                if leftType == .major { return true }
                if rightType == .major { return false }
                return leftType.rawValue < rightType.rawValue
            }
            return lhs.displayText.localizedCaseInsensitiveCompare(rhs.displayText) == .orderedAscending
        }
    }

    func fetchSpecializationJoinLimits(type: CommunitySpecializationType?) async throws -> [SpecializationJoinLimit] {
        var endpoint = "/v1/me/specializations/join-limits"
        if let type, type != .unknown {
            endpoint += "?type=\(type.rawValue)"
        }
        let response: SpecializationJoinLimitListResponseDTO = try await apiClient.get(endpoint)
        return response.items.map(SpecializationJoinLimit.init(dto:))
    }

    func searchCommunities(query: String, limit: Int, cursor: String?, kind: CommunitySearchKind?) async throws -> SearchResultPage<CommunitySearchResult> {
        let encodedQuery = URLQueryEncoding.encode(query)
        var endpoint = "/v1/communities/search?query=\(encodedQuery)&limit=\(limit > 0 ? limit : defaultLimit)"
        if let kindValue = kind?.queryValue {
            endpoint += "&kind=\(kindValue)"
        }
        if let cursor, !cursor.isEmpty {
            endpoint += "&cursor=\(URLQueryEncoding.encode(cursor))"
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

    func followSpecialization(id: Int) async throws {
        let _: EmptyResponse = try await apiClient.post("/v1/specializations/\(id)/follow", body: EmptyBody())
    }

    func unfollowSpecialization(id: Int) async throws {
        try await apiClient.delete("/v1/specializations/\(id)/follow")
    }

    func joinSpecialization(id: Int) async throws {
        let _: EmptyResponse = try await apiClient.post("/v1/specializations/\(id)/join", body: EmptyBody())
    }

    func unjoinSpecialization(id: Int) async throws {
        try await apiClient.delete("/v1/specializations/\(id)/join")
    }

    func fetchCommunityPermissions(communityId: Int) async throws -> CommunityPermissions {
        let dto: CommunityPermissionsDTO = try await apiClient.get("/v1/communities/\(communityId)/permissions")
        return CommunityPermissions(dto: dto)
    }
}

private struct EmptyBody: Codable {}
