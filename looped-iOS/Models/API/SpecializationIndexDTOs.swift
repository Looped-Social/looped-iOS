import Foundation

struct SpecializationIndexResponseDTO: Codable {
    let items: [SpecializationIndexItemDTO]
}

struct SpecializationIndexItemDTO: Codable {
    let id: Int
    let name: String
    let shortName: String?
    let bannerImageUrl: String?
    let iconImageUrl: String?
    let icon: CommunityIcon?
}
