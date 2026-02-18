import Foundation

struct PostViewerCapabilities: Codable, Equatable {
    let canInteract: Bool
    let canPost: Bool
    let canComment: Bool
    let canReply: Bool
    let canLike: Bool
    let canVote: Bool
    let canRepost: Bool
    let canSave: Bool
    let lockReason: PostViewerLockReason?
    let requiresVerification: Bool
    let requiresJoin: Bool
    let lockContext: PostViewerLockContext?
    let primaryUnlockAction: PostViewerPrimaryUnlockAction?
}

enum PostViewerLockReason: String, Codable, Equatable {
    case communityNotVerified = "COMMUNITY_NOT_VERIFIED"
    case specializationNotJoined = "SPECIALIZATION_NOT_JOINED"
    case specializationVerificationRequired = "SPECIALIZATION_VERIFICATION_REQUIRED"
    case verificationExpired = "VERIFICATION_EXPIRED"
    case communityBanned = "COMMUNITY_BANNED"
    case unknownRestriction = "UNKNOWN_RESTRICTION"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = PostViewerLockReason(rawValue: rawValue) ?? .unknownRestriction
    }
}

extension PostViewerCapabilities {
    init(dto: PostViewerCapabilitiesDTO) {
        canInteract = dto.canInteract ?? false
        canPost = dto.canPost ?? dto.canInteract ?? false
        canComment = dto.canComment ?? false
        canReply = dto.canReply ?? false
        canLike = dto.canLike ?? false
        canVote = dto.canVote ?? false
        canRepost = dto.canRepost ?? false
        canSave = dto.canSave ?? true
        lockReason = dto.lockReason.map { PostViewerLockReason(rawValue: $0) ?? .unknownRestriction }
        requiresVerification = dto.requiresVerification ?? false
        requiresJoin = dto.requiresJoin ?? false
        lockContext = dto.lockContext.map(PostViewerLockContext.init(dto:))
        primaryUnlockAction = dto.primaryUnlockAction.map(PostViewerPrimaryUnlockAction.init(dto:))
    }

    func lockTitle(for _: String) -> String {
        switch lockReason {
        case .some(.specializationNotJoined), .some(.specializationVerificationRequired):
            return "Join required"
        case .some(.communityNotVerified), .some(.verificationExpired):
            return "Verification required"
        case .some(.communityBanned):
            return "Action unavailable"
        case .some(.unknownRestriction), .none:
            return "Action unavailable"
        }
    }

    func lockMessage(for verb: String) -> String {
        switch lockReason {
        case .some(.specializationNotJoined):
            return "Join this major or field to \(verb)."
        case .some(.specializationVerificationRequired):
            return "Verify first, then join this major or field to \(verb)."
        case .some(.communityNotVerified):
            return "You must be verified in this community to \(verb). Go to that community and tap Verify."
        case .some(.verificationExpired):
            return "Your verification expired. Verify again to \(verb)."
        case .some(.communityBanned):
            return "You can’t \(verb) in this community."
        case .some(.unknownRestriction), .none:
            return "You can’t \(verb) right now."
        }
    }
}

struct PostViewerLockContext: Codable, Equatable {
    let communityId: Int?
    let communityName: String?
    let communityKind: CommunityKind
    let specializationId: Int?
    let specializationName: String?
    let specializationType: CommunitySpecializationType
    let joinCreditsRemaining: Int?
    let joinCreditsLimit: Int?
    let joinCooldownActive: Bool
    let joinCooldownEndsAt: Date?
    let requiredVerificationKind: SpecializationJoinRequiresVerificationKind?
    let verifyTargetCommunityId: Int?
    let verifyTargetCommunityName: String?
    let alreadyVerifiedElsewhere: Bool

    private enum CodingKeys: String, CodingKey {
        case communityId
        case communityName
        case communityKind
        case specializationId
        case specializationName
        case specializationType
        case joinCreditsRemaining
        case joinCreditsLimit
        case joinCooldownActive
        case joinCooldownEndsAt
        case requiredVerificationKind
        case verifyTargetCommunityId
        case verifyTargetCommunityName
        case alreadyVerifiedElsewhere
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        communityId = try container.decodeIfPresent(Int.self, forKey: .communityId)
        communityName = try container.decodeIfPresent(String.self, forKey: .communityName)

        let communityKindRaw = try container.decodeIfPresent(String.self, forKey: .communityKind)
        communityKind = CommunityKind.fromApi(communityKindRaw)

        specializationId = try container.decodeIfPresent(Int.self, forKey: .specializationId)
        specializationName = try container.decodeIfPresent(String.self, forKey: .specializationName)

        let specializationTypeRaw = try container.decodeIfPresent(String.self, forKey: .specializationType)
        specializationType = CommunitySpecializationType.fromApi(specializationTypeRaw)

        joinCreditsRemaining = try container.decodeIfPresent(Int.self, forKey: .joinCreditsRemaining)
        joinCreditsLimit = try container.decodeIfPresent(Int.self, forKey: .joinCreditsLimit)
        joinCooldownActive = try container.decodeIfPresent(Bool.self, forKey: .joinCooldownActive) ?? false
        joinCooldownEndsAt = try container.decodeIfPresent(Date.self, forKey: .joinCooldownEndsAt)

        let requiredKindRaw = try container.decodeIfPresent(String.self, forKey: .requiredVerificationKind)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        requiredVerificationKind = requiredKindRaw
            .flatMap(SpecializationJoinRequiresVerificationKind.init(rawValue:))

        verifyTargetCommunityId = try container.decodeIfPresent(Int.self, forKey: .verifyTargetCommunityId)
        verifyTargetCommunityName = try container.decodeIfPresent(String.self, forKey: .verifyTargetCommunityName)
        alreadyVerifiedElsewhere = try container.decodeIfPresent(Bool.self, forKey: .alreadyVerifiedElsewhere) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(communityId, forKey: .communityId)
        try container.encodeIfPresent(communityName, forKey: .communityName)
        try container.encode(communityKind.rawValue, forKey: .communityKind)
        try container.encodeIfPresent(specializationId, forKey: .specializationId)
        try container.encodeIfPresent(specializationName, forKey: .specializationName)
        try container.encode(specializationType.rawValue, forKey: .specializationType)
        try container.encodeIfPresent(joinCreditsRemaining, forKey: .joinCreditsRemaining)
        try container.encodeIfPresent(joinCreditsLimit, forKey: .joinCreditsLimit)
        try container.encode(joinCooldownActive, forKey: .joinCooldownActive)
        try container.encodeIfPresent(joinCooldownEndsAt, forKey: .joinCooldownEndsAt)
        try container.encodeIfPresent(requiredVerificationKind?.rawValue, forKey: .requiredVerificationKind)
        try container.encodeIfPresent(verifyTargetCommunityId, forKey: .verifyTargetCommunityId)
        try container.encodeIfPresent(verifyTargetCommunityName, forKey: .verifyTargetCommunityName)
        try container.encode(alreadyVerifiedElsewhere, forKey: .alreadyVerifiedElsewhere)
    }
}

extension PostViewerLockContext {
    init(dto: PostViewerLockContextDTO) {
        communityId = dto.communityId
        communityName = dto.communityName
        communityKind = CommunityKind.fromApi(dto.communityKind)
        specializationId = dto.specializationId
        specializationName = dto.specializationName
        specializationType = CommunitySpecializationType.fromApi(dto.specializationType)
        joinCreditsRemaining = dto.joinCreditsRemaining
        joinCreditsLimit = dto.joinCreditsLimit
        joinCooldownActive = dto.joinCooldownActive ?? false
        joinCooldownEndsAt = dto.joinCooldownEndsAt
        requiredVerificationKind = dto.requiredVerificationKind
            .flatMap(SpecializationJoinRequiresVerificationKind.init(rawValue:))
        verifyTargetCommunityId = dto.verifyTargetCommunityId
        verifyTargetCommunityName = dto.verifyTargetCommunityName
        alreadyVerifiedElsewhere = dto.alreadyVerifiedElsewhere ?? false
    }
}

enum PostViewerPrimaryUnlockActionType: String, Codable, Equatable {
    case verifyCommunity = "VERIFY_COMMUNITY"
    case joinSpecialization = "JOIN_SPECIALIZATION"
    case verifyParentThenJoin = "VERIFY_PARENT_THEN_JOIN"
    case none = "NONE"
    case unknown = "UNKNOWN"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = PostViewerPrimaryUnlockActionType(rawValue: rawValue) ?? .unknown
    }
}

struct PostViewerPrimaryUnlockAction: Codable, Equatable {
    let type: PostViewerPrimaryUnlockActionType
    let communityId: Int?
    let specializationId: Int?
    let label: String?
}

extension PostViewerPrimaryUnlockAction {
    init(dto: PostViewerPrimaryUnlockActionDTO) {
        type = dto.type.map { PostViewerPrimaryUnlockActionType(rawValue: $0) ?? .unknown } ?? .unknown
        communityId = dto.communityId
        specializationId = dto.specializationId
        label = dto.label
    }
}
