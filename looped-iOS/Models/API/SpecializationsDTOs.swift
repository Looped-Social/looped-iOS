import Foundation

struct SpecializationsRecommendedResponseDTO: Codable {
    let majors: [CommunityRecommendedDTO]?
    let departments: [CommunityRecommendedDTO]?
    let items: [CommunityRecommendedDTO]?
}

