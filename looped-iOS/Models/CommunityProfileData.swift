import Foundation

struct CommunityProfileData: Identifiable, Equatable {
    let id: Int
    var name: String
    var shortName: String?
    var description: String
    var kind: CommunityKind
    var specializationType: CommunitySpecializationType
    /// Number of active verified members for this community (backend `member_count`).
    /// Not affected by follow/unfollow or join/leave actions.
    var memberCount: Int
    var bannerImageUrl: String? = nil
    var profileImageUrl: String? = nil
    var imageUrl: String?
    var isFollowing: Bool
    var isJoined: Bool
    var joinLimit: SpecializationJoinLimit?
}

extension CommunityProfileData {
    var bannerDisplayImageUrl: String? {
        bannerImageUrl?.trimmedNonEmpty ?? imageUrl?.trimmedNonEmpty
    }

    var profileDisplayImageUrl: String? {
        profileImageUrl?.trimmedNonEmpty ?? imageUrl?.trimmedNonEmpty
    }
}

extension CommunityProfileData {
    init(community: CommunitySearchResult) {
        self.id = community.id
        self.name = community.name
        self.shortName = community.shortName
        self.description = community.description
        self.kind = community.kind
        self.specializationType = community.specializationType
        self.memberCount = community.memberCount
        self.bannerImageUrl = community.bannerImageUrl
        self.profileImageUrl = community.profileImageUrl
        self.imageUrl = community.imageUrl
        self.isFollowing = community.isFollowing ?? false
        self.isJoined = community.isJoined ?? false
        self.joinLimit = nil
    }

    init(details: CommunityDetailsDTO) {
        self.id = details.id
        self.name = details.name
        self.shortName = details.shortName
        self.description = details.description ?? ""
        self.kind = CommunityKind.fromApi(details.kind)
        let parsedType = CommunitySpecializationType(rawValue: details.specializationType ?? "") ?? .unknown
        if parsedType == .unknown {
            self.specializationType = CommunitySpecializationType(rawValue: details.kind ?? "") ?? .unknown
        } else {
            self.specializationType = parsedType
        }
        self.memberCount = details.memberCount ?? 0
        self.bannerImageUrl = details.bannerImageUrl
        self.profileImageUrl = details.profileImageUrl
        self.imageUrl = details.imageUrl
        self.isFollowing = details.isFollowing ?? false
        self.isJoined = details.isJoined ?? false
        self.joinLimit = details.joinLimit.map(SpecializationJoinLimit.init(dto:))
    }

    init(details: CommunityDetailsDTO, fallback: CommunityProfileData) {
        self.id = details.id
        self.name = details.name
        self.shortName = details.shortName ?? fallback.shortName

        let detailsDescription = (details.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = detailsDescription.isEmpty ? fallback.description : detailsDescription

        let parsedKind = CommunityKind.fromApi(details.kind)
        self.kind = parsedKind == .unknown ? fallback.kind : parsedKind

        let parsedType = CommunitySpecializationType(rawValue: details.specializationType ?? "") ?? .unknown
        if parsedType == .unknown {
            let inferred = CommunitySpecializationType(rawValue: details.kind ?? "") ?? .unknown
            self.specializationType = inferred == .unknown ? fallback.specializationType : inferred
        } else {
            self.specializationType = parsedType
        }

        self.memberCount = details.memberCount ?? fallback.memberCount

        let detailsImageUrl = details.imageUrl?.trimmedNonEmpty
        self.imageUrl = detailsImageUrl ?? fallback.imageUrl

        if let detailsBannerImageUrl = details.bannerImageUrl?.trimmedNonEmpty {
            self.bannerImageUrl = detailsBannerImageUrl
        } else if detailsImageUrl != nil {
            self.bannerImageUrl = nil
        } else {
            self.bannerImageUrl = fallback.bannerImageUrl
        }

        if let detailsProfileImageUrl = details.profileImageUrl?.trimmedNonEmpty {
            self.profileImageUrl = detailsProfileImageUrl
        } else if detailsImageUrl != nil {
            self.profileImageUrl = nil
        } else {
            self.profileImageUrl = fallback.profileImageUrl
        }

        self.isFollowing = details.isFollowing ?? fallback.isFollowing
        self.isJoined = details.isJoined ?? fallback.isJoined
        self.joinLimit = details.joinLimit.map(SpecializationJoinLimit.init(dto:)) ?? fallback.joinLimit
    }

    init(
        summary: CommunitySummary,
        description: String = "",
        imageUrl: String? = nil,
        bannerImageUrl: String? = nil,
        profileImageUrl: String? = nil
    ) {
        self.id = summary.id
        self.name = summary.name
        self.shortName = summary.shortName
        self.description = description
        self.kind = summary.kind
        self.specializationType = .unknown
        self.memberCount = summary.memberCount
        self.bannerImageUrl = bannerImageUrl
        self.profileImageUrl = profileImageUrl
        self.imageUrl = imageUrl
        self.isFollowing = true
        self.isJoined = false
        self.joinLimit = nil
    }

    init?(loop: SearchResultLoop) {
        guard let backendId = loop.backendId else { return nil }
        self.id = backendId
        self.name = loop.name
        self.shortName = loop.shortName
        self.description = loop.description
        self.kind = loop.kind
        self.specializationType = loop.specializationType
        self.memberCount = loop.memberCount
        self.bannerImageUrl = loop.bannerImageUrl
        self.profileImageUrl = loop.profileImageUrl
        self.imageUrl = loop.imageUrl
        self.isFollowing = false
        self.isJoined = false
        self.joinLimit = nil
    }
}

extension CommunityProfileData {
    init(displayCommunity: DisplayCommunity) {
        self.id = displayCommunity.id
        self.name = displayCommunity.name
        self.shortName = displayCommunity.shortName
        self.description = ""
        self.kind = displayCommunity.kind
        self.specializationType = displayCommunity.specializationType ?? .unknown
        self.memberCount = 0
        self.bannerImageUrl = nil
        self.profileImageUrl = nil
        self.imageUrl = nil
        self.isFollowing = false
        self.isJoined = false
        self.joinLimit = nil
    }
}

extension CommunityProfileData {
    var specializationLabel: String? {
        guard kind == .specialization else { return nil }
        return specializationType.displayName
    }
}
