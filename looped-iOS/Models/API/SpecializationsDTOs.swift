import Foundation

struct SpecializationsRecommendedResponseDTO: Codable {
    let majors: [CommunityRecommendedDTO]?
    let fields: [CommunityRecommendedDTO]?
    let items: [CommunityRecommendedDTO]?
}
