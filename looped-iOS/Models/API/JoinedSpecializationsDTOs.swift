import Foundation

struct JoinedSpecializationsResponseDTO: Decodable {
    let items: [JoinedSpecializationDTO]
    let nextCursor: String?
}

struct JoinedSpecializationDTO: Decodable {
    let id: Int
    let kind: String?
    let name: String
    let shortName: String?
    let specializationType: String?
    let iconImageUrl: String?
    let icon: CommunityIcon?
    let memberCount: Int?
    let joinedAt: Date?
}
