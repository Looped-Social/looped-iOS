import Foundation

enum CommunityKind: String, Codable {
    case company
    case school
    case specialization
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CommunityKind.fromApi(rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let rawValue = self == .unknown ? "unknown" : self.rawValue
        try container.encode(rawValue)
    }

    static func fromApi(_ rawValue: String?) -> CommunityKind {
        let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        guard !normalized.isEmpty else { return .unknown }
        if normalized == "major" || normalized == "field" {
            return .specialization
        }
        return CommunityKind(rawValue: normalized) ?? .unknown
    }
}

enum CommunitySpecializationType: String, Codable {
    case major
    case field
    case unknown

    static func fromApi(_ rawValue: String?) -> CommunitySpecializationType {
        let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        guard !normalized.isEmpty else { return .unknown }
        return CommunitySpecializationType(rawValue: normalized) ?? .unknown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CommunitySpecializationType.fromApi(rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let rawValue = self == .unknown ? "unknown" : self.rawValue
        try container.encode(rawValue)
    }

    var displayName: String? {
        switch self {
        case .major:
            return "Major"
        case .field:
            return "Field"
        case .unknown:
            return nil
        }
    }
}

enum CommunitySearchKind: String {
    case company
    case school
    case specialization
    case major
    case field
    case unknown

    var queryValue: String? {
        self == .unknown ? nil : rawValue
    }
}

struct CommunitySummary: Identifiable, Equatable {
    let id: Int
    let name: String
    let shortName: String?
    let kind: CommunityKind
    /// Number of active verified members for this community (backend `member_count`).
    let memberCount: Int
    let isPinned: Bool
    let sortOrder: Int?
    let canPost: Bool
}

struct CommunitySearchResult: Identifiable, Equatable {
    let id: Int
    let name: String
    let shortName: String?
    let description: String
    let kind: CommunityKind
    let specializationType: CommunitySpecializationType
    /// Number of active verified members for this community (backend `member_count`).
    let memberCount: Int
    let imageUrl: String?
    let icon: CommunityIcon?
    let isFollowing: Bool?
    let isJoined: Bool?

    init(
        id: Int,
        name: String,
        shortName: String? = nil,
        description: String,
        kind: CommunityKind,
        specializationType: CommunitySpecializationType = .unknown,
        memberCount: Int,
        imageUrl: String? = nil,
        icon: CommunityIcon? = nil,
        isFollowing: Bool? = nil,
        isJoined: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.description = description
        self.kind = kind
        self.specializationType = specializationType
        self.memberCount = memberCount
        self.imageUrl = imageUrl
        self.icon = icon
        self.isFollowing = isFollowing
        self.isJoined = isJoined
    }
}

struct CommunityPermissions: Equatable {
    let canPost: Bool
    let requiresVerification: Bool
    let requiresJoin: Bool
}

extension CommunityPermissions {
    init(dto: CommunityPermissionsDTO) {
        canPost = dto.canPost
        requiresVerification = dto.requiresVerification
        requiresJoin = dto.requiresJoin ?? false
    }
}

extension CommunitySummary {
    init(dto: CommunityFollowDTO) {
        id = dto.id
        name = dto.name
        shortName = dto.shortName
        kind = CommunityKind.fromApi(dto.kind)
        memberCount = dto.memberCount ?? 0
        isPinned = dto.isPinned ?? false
        sortOrder = dto.sortOrder
        canPost = dto.canPost ?? false
    }
}

extension CommunitySearchResult {
    func withIcon(_ icon: CommunityIcon?) -> CommunitySearchResult {
        CommunitySearchResult(
            id: id,
            name: name,
            shortName: shortName,
            description: description,
            kind: kind,
            specializationType: specializationType,
            memberCount: memberCount,
            imageUrl: imageUrl,
            icon: icon,
            isFollowing: isFollowing,
            isJoined: isJoined
        )
    }

    init(dto: CommunitySearchDTO) {
        id = dto.id
        name = dto.name
        shortName = dto.shortName
        description = dto.description ?? ""
        kind = CommunityKind.fromApi(dto.kind)
        let parsedType = CommunitySpecializationType.fromApi(dto.specializationType)
        specializationType = parsedType != .unknown
            ? parsedType
            : CommunitySpecializationType.fromApi(dto.kind)
        memberCount = dto.memberCount ?? 0
        imageUrl = dto.imageUrl
        icon = dto.icon?.normalizedOrNil()
        isFollowing = dto.isFollowing
        isJoined = dto.isJoined
    }

    init(dto: CommunityRecommendedDTO) {
        id = dto.id
        name = dto.name
        shortName = dto.shortName
        description = dto.description ?? ""
        kind = CommunityKind.fromApi(dto.kind)
        let parsedType = CommunitySpecializationType.fromApi(dto.specializationType)
        specializationType = parsedType != .unknown
            ? parsedType
            : CommunitySpecializationType.fromApi(dto.kind)
        memberCount = dto.memberCount ?? 0
        imageUrl = dto.imageUrl
        icon = dto.icon?.normalizedOrNil()
        isFollowing = dto.isFollowing
        isJoined = dto.isJoined
    }
}

// `CommunityPermissionsDTO` -> `CommunityPermissions` mapping is defined above.
