import Foundation

struct DisplayCommunity: Codable, Equatable {
    let id: Int
    let name: String
    let shortName: String?
    let kind: CommunityKind
    let specializationType: CommunitySpecializationType?
    let iconImageUrl: String?
    let icon: CommunityIcon?

    init(
        id: Int,
        name: String,
        shortName: String?,
        kind: CommunityKind,
        specializationType: CommunitySpecializationType?,
        iconImageUrl: String? = nil,
        icon: CommunityIcon? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.kind = kind
        self.specializationType = specializationType
        self.iconImageUrl = iconImageUrl
        self.icon = icon
    }

    var displayText: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "Community" : trimmed
        return resolved
    }

    var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    var preferredSpecializationIcon: CommunityIcon? {
        CommunityIcon.imageURL(iconImageUrl) ?? icon?.normalizedOrNil()
    }
}

extension DisplayCommunity {
    init(dto: DisplayCommunityDTO) {
        id = dto.id
        name = dto.name
        shortName = dto.shortName
        kind = CommunityKind.fromApi(dto.kind)
        let parsedType = CommunitySpecializationType(rawValue: dto.specializationType ?? "") ?? .unknown
        if parsedType == .unknown {
            specializationType = CommunitySpecializationType(rawValue: dto.kind ?? "")
        } else {
            specializationType = parsedType
        }
        iconImageUrl = dto.iconImageUrl
        icon = dto.icon?.normalizedOrNil()
    }

    init(verification: CommunityVerification) {
        id = verification.communityId
        name = verification.communityName
        shortName = nil
        kind = verification.communityKind
        specializationType = nil
        iconImageUrl = nil
        icon = nil
    }
}
