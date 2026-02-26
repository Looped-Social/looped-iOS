import Foundation

final class PeopleRecommendationService: PeopleRecommendationServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchRails(
        surface: PeopleRecommendationSurface,
        communityId: Int?,
        rails: [PeopleRecommendationRail]?,
        limitPerRail: Int?
    ) async throws -> PeopleRecommendationRailsBundle {
        var endpoint = "/v1/recommendations/people/rails?surface=\(surface.rawValue)"
        if let communityId {
            endpoint += "&community_id=\(communityId)"
        }
        if let rails, !rails.isEmpty {
            let railsCSV = rails.map(\.rawValue).joined(separator: ",")
            endpoint += "&rails=\(URLQueryEncoding.encode(railsCSV))"
        }
        if let limitPerRail {
            endpoint += "&limit_per_rail=\(max(1, min(limitPerRail, 25)))"
        }

        let response: PeopleRecommendationRailsResponseDTO = try await apiClient.get(endpoint)
        return try PeopleRecommendationRailsBundle(dto: response)
    }

    func fetchRail(
        rail: PeopleRecommendationRail,
        surface: PeopleRecommendationSurface,
        communityId: Int?,
        limit: Int?,
        cursor: String?
    ) async throws -> PeopleRecommendationRailPage {
        var endpoint = "/v1/recommendations/people/\(rail.rawValue)?surface=\(surface.rawValue)"
        if let communityId {
            endpoint += "&community_id=\(communityId)"
        }
        if let limit {
            endpoint += "&limit=\(max(1, min(limit, 50)))"
        }
        if let cursor, !cursor.isEmpty {
            endpoint += "&cursor=\(URLQueryEncoding.encode(cursor))"
        }

        let response: PeopleRecommendationRailResponseDTO = try await apiClient.get(endpoint)
        return try PeopleRecommendationRailPage(dto: response)
    }

    func sendFeedback(events: [PeopleRecommendationFeedbackEvent]) async throws -> PeopleRecommendationFeedbackResponse {
        guard !events.isEmpty else {
            return PeopleRecommendationFeedbackResponse(
                requestId: UUID().uuidString,
                accepted: 0,
                deduped: 0,
                dropped: 0,
                suppressedCandidateIds: []
            )
        }

        let request = PeopleRecommendationFeedbackRequestDTO(events: Array(events.prefix(200)))
        return try await apiClient.post("/v1/recommendations/people/feedback", body: request)
    }
}

private extension PeopleRecommendationRailsBundle {
    init(dto: PeopleRecommendationRailsResponseDTO) throws {
        requestId = dto.requestId
        surface = PeopleRecommendationSurface(rawValue: dto.surface) ?? .search
        community = dto.community.map(PeopleRecommendationCommunity.init(dto:))
        rails = try dto.rails.map { railDTO in
            try PeopleRecommendationRailPage(dto: railDTO, requestIdOverride: dto.requestId)
        }
        experiment = dto.experiment.map(PeopleRecommendationExperiment.init(dto:))
        degraded = dto.degraded
        generatedAt = dto.generatedAt
    }
}

private extension PeopleRecommendationRailPage {
    init(dto: PeopleRecommendationRailResponseDTO, requestIdOverride: String? = nil) throws {
        guard let rail = PeopleRecommendationRail(rawValue: dto.rail) else {
            throw APIError.invalidResponse
        }
        requestId = requestIdOverride ?? dto.requestId ?? ""
        self.rail = rail
        title = dto.title
        items = dto.items.map(PeopleRecommendationItem.init(dto:))
        nextCursor = dto.nextCursor
        hasMore = dto.hasMore
        degraded = dto.degraded
        community = dto.community.map(PeopleRecommendationCommunity.init(dto:))
        experiment = dto.experiment.map(PeopleRecommendationExperiment.init(dto:))
    }
}

private extension PeopleRecommendationItem {
    init(dto: PeopleRecommendationItemDTO) {
        recommendationId = dto.recommendationId
        user = PeopleRecommendationUser(dto: dto.user)
        reasons = dto.reasons.map(PeopleRecommendationReason.init(dto:))
        actions = PeopleRecommendationActions(dto: dto.actions)
        tracking = PeopleRecommendationTracking(dto: dto.tracking)
    }
}

private extension PeopleRecommendationUser {
    init(dto: PeopleRecommendationUserDTO) {
        id = dto.id
        let trimmedUsername = dto.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedRawHandle = dto.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        handle = trimmedUsername.isEmpty ? trimmedRawHandle : trimmedUsername
        let trimmedDisplayName = dto.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedFirstName = dto.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedLastName = dto.lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName = [trimmedFirstName, trimmedLastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !trimmedDisplayName.isEmpty {
            displayName = trimmedDisplayName
        } else if !fullName.isEmpty {
            displayName = fullName
        } else if !trimmedHandle.isEmpty {
            displayName = trimmedHandle
        } else {
            displayName = "Looped User"
        }
        avatarURL = dto.avatarUrl
        headline = dto.headline
        community = dto.community.map(PeopleRecommendationCommunity.init(dto:))
    }
}

private extension PeopleRecommendationReason {
    init(dto: PeopleRecommendationReasonDTO) {
        code = dto.code
        text = dto.text
    }
}

private extension PeopleRecommendationActions {
    init(dto: PeopleRecommendationActionsDTO) {
        canConnect = dto.canConnect
        canHide = dto.canHide
        canLessLikeThis = dto.canLessLikeThis
    }
}

private extension PeopleRecommendationTracking {
    init(dto: PeopleRecommendationTrackingDTO) {
        token = dto.token
        position = dto.position
    }
}

private extension PeopleRecommendationCommunity {
    init(dto: PeopleRecommendationCommunityDTO) {
        id = dto.id
        name = dto.name
    }
}

private extension PeopleRecommendationExperiment {
    init(dto: PeopleRecommendationExperimentDTO) {
        key = dto.key
        bucket = dto.bucket
    }
}
