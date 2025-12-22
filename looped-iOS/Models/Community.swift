import Foundation

enum CommunityKind: String, Codable {
    case company
    case school
    case profession
    case sector
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CommunityKind(rawValue: rawValue) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let rawValue = self == .unknown ? "unknown" : self.rawValue
        try container.encode(rawValue)
    }
}

struct CommunitySummary: Identifiable, Equatable {
    let id: Int
    let name: String
    let kind: CommunityKind
    let memberCount: Int
    let isPinned: Bool
    let sortOrder: Int?
    let canPost: Bool
}

struct CommunitySearchResult: Identifiable, Equatable {
    let id: Int
    let name: String
    let description: String
    let kind: CommunityKind
    let memberCount: Int
    let imageUrl: String?
    let isFollowing: Bool?

    init(
        id: Int,
        name: String,
        description: String,
        kind: CommunityKind,
        memberCount: Int,
        imageUrl: String? = nil,
        isFollowing: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.kind = kind
        self.memberCount = memberCount
        self.imageUrl = imageUrl
        self.isFollowing = isFollowing
    }
}

extension CommunitySummary {
    init(dto: CommunityFollowDTO) {
        id = dto.id
        name = dto.name
        kind = CommunityKind(rawValue: dto.kind ?? "") ?? .unknown
        memberCount = dto.memberCount ?? 0
        isPinned = dto.isPinned ?? false
        sortOrder = dto.sortOrder
        canPost = dto.canPost ?? false
    }
}

extension CommunitySearchResult {
    init(dto: CommunitySearchDTO) {
        id = dto.id
        name = dto.name
        description = dto.description
        kind = CommunityKind(rawValue: dto.kind ?? "") ?? .unknown
        memberCount = dto.memberCount ?? 0
        imageUrl = dto.imageUrl
        isFollowing = nil
    }

    init(dto: CommunityRecommendedDTO) {
        id = dto.id
        name = dto.name
        description = dto.description
        kind = CommunityKind(rawValue: dto.kind ?? "") ?? .unknown
        memberCount = dto.memberCount ?? 0
        imageUrl = dto.imageUrl
        isFollowing = dto.isFollowing
    }
}
