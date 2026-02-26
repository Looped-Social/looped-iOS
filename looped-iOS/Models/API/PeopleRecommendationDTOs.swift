import Foundation

struct PeopleRecommendationRailsResponseDTO: Decodable {
    let requestId: String
    let surface: String
    let community: PeopleRecommendationCommunityDTO?
    let rails: [PeopleRecommendationRailResponseDTO]
    let experiment: PeopleRecommendationExperimentDTO?
    let degraded: Bool
    let generatedAt: Date
}

struct PeopleRecommendationRailResponseDTO: Decodable {
    let requestId: String?
    let rail: String
    let title: String
    let items: [PeopleRecommendationItemDTO]
    let nextCursor: String?
    let hasMore: Bool
    let degraded: Bool
    let community: PeopleRecommendationCommunityDTO?
    let experiment: PeopleRecommendationExperimentDTO?
}

struct PeopleRecommendationItemDTO: Decodable {
    let recommendationId: String
    let user: PeopleRecommendationUserDTO
    let reasons: [PeopleRecommendationReasonDTO]
    let actions: PeopleRecommendationActionsDTO
    let tracking: PeopleRecommendationTrackingDTO
}

struct PeopleRecommendationUserDTO: Decodable {
    let id: Int
    let handle: String
    let username: String?
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let headline: String?
    let community: PeopleRecommendationCommunityDTO?
}

struct PeopleRecommendationCommunityDTO: Decodable {
    let id: Int
    let name: String
}

struct PeopleRecommendationReasonDTO: Decodable {
    let code: String
    let text: String
}

struct PeopleRecommendationActionsDTO: Decodable {
    let canConnect: Bool
    let canHide: Bool
    let canLessLikeThis: Bool
}

struct PeopleRecommendationTrackingDTO: Decodable {
    let token: String
    let position: Int
}

struct PeopleRecommendationExperimentDTO: Decodable {
    let key: String
    let bucket: String
}

struct PeopleRecommendationFeedbackRequestDTO: Encodable {
    let events: [PeopleRecommendationFeedbackEvent]
}
