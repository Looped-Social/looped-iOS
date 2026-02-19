import Foundation

enum LockedFeedActionType: String, Equatable, Sendable {
    case like
    case comment
    case post

    var verb: String {
        switch self {
        case .like:
            return "like"
        case .comment:
            return "comment"
        case .post:
            return "post"
        }
    }
}

enum LockReason: Equatable, Sendable {
    case communityVerificationRequired(
        communityId: Int?,
        communityName: String,
        fieldName: String?,
        majorName: String?,
        joinCreditsRemaining: Int?,
        alreadyVerifiedElsewhere: Bool,
        communityButtonShortName: String?
    )
    case specializationJoinRequired(
        communityId: Int,
        communityName: String,
        fieldName: String?,
        majorName: String?,
        joinCreditsRemaining: Int?,
        alreadyVerifiedElsewhere: Bool
    )
    case joinRequiresVerificationFirst(
        communityId: Int?,
        communityName: String,
        fieldName: String?,
        majorName: String?,
        joinCreditsRemaining: Int?,
        alreadyVerifiedElsewhere: Bool,
        requiredVerificationKind: SpecializationJoinRequiresVerificationKind?,
        verifyTargetCommunityId: Int?,
        verifyTargetCommunityName: String?
    )
}

extension LockReason {
    var communityId: Int? {
        switch self {
        case .communityVerificationRequired(let communityId, _, _, _, _, _, _):
            return communityId
        case .specializationJoinRequired(let communityId, _, _, _, _, _):
            return communityId
        case .joinRequiresVerificationFirst(let communityId, _, _, _, _, _, _, _, _):
            return communityId
        }
    }

    var communityName: String {
        switch self {
        case .communityVerificationRequired(_, let communityName, _, _, _, _, _):
            return communityName
        case .specializationJoinRequired(_, let communityName, _, _, _, _):
            return communityName
        case .joinRequiresVerificationFirst(_, let communityName, _, _, _, _, _, _, _):
            return communityName
        }
    }

    var fieldName: String? {
        switch self {
        case .communityVerificationRequired(_, _, let fieldName, _, _, _, _):
            return fieldName
        case .specializationJoinRequired(_, _, let fieldName, _, _, _):
            return fieldName
        case .joinRequiresVerificationFirst(_, _, let fieldName, _, _, _, _, _, _):
            return fieldName
        }
    }

    var majorName: String? {
        switch self {
        case .communityVerificationRequired(_, _, _, let majorName, _, _, _):
            return majorName
        case .specializationJoinRequired(_, _, _, let majorName, _, _):
            return majorName
        case .joinRequiresVerificationFirst(_, _, _, let majorName, _, _, _, _, _):
            return majorName
        }
    }

    var joinCreditsRemaining: Int? {
        switch self {
        case .communityVerificationRequired(_, _, _, _, let joinCreditsRemaining, _, _):
            return joinCreditsRemaining
        case .specializationJoinRequired(_, _, _, _, let joinCreditsRemaining, _):
            return joinCreditsRemaining
        case .joinRequiresVerificationFirst(_, _, _, _, let joinCreditsRemaining, _, _, _, _):
            return joinCreditsRemaining
        }
    }

    var alreadyVerifiedElsewhere: Bool {
        switch self {
        case .communityVerificationRequired(_, _, _, _, _, let alreadyVerifiedElsewhere, _):
            return alreadyVerifiedElsewhere
        case .specializationJoinRequired(_, _, _, _, _, let alreadyVerifiedElsewhere):
            return alreadyVerifiedElsewhere
        case .joinRequiresVerificationFirst(_, _, _, _, _, let alreadyVerifiedElsewhere, _, _, _):
            return alreadyVerifiedElsewhere
        }
    }

    var requiredVerificationKind: SpecializationJoinRequiresVerificationKind? {
        switch self {
        case .joinRequiresVerificationFirst(_, _, _, _, _, _, let kind, _, _):
            return kind
        case .communityVerificationRequired, .specializationJoinRequired:
            return nil
        }
    }

    var verifyTargetCommunityId: Int? {
        switch self {
        case .joinRequiresVerificationFirst(_, _, _, _, _, _, _, let verifyTargetCommunityId, _):
            return verifyTargetCommunityId
        case .communityVerificationRequired(let communityId, _, _, _, _, _, _):
            return communityId
        case .specializationJoinRequired:
            return nil
        }
    }

    var verifyTargetCommunityName: String? {
        switch self {
        case .joinRequiresVerificationFirst(_, _, _, _, _, _, _, _, let verifyTargetCommunityName):
            return verifyTargetCommunityName
        case .communityVerificationRequired(_, let communityName, _, _, _, _, _):
            return communityName
        case .specializationJoinRequired:
            return nil
        }
    }

    var sessionPresentationTypeKey: String {
        switch self {
        case .communityVerificationRequired:
            return "community_verification_required"
        case .specializationJoinRequired:
            return "specialization_join_required"
        case .joinRequiresVerificationFirst:
            return "join_requires_verification_first"
        }
    }

    var specializationDisplayName: String {
        if let majorName = majorName?.trimmingCharacters(in: .whitespacesAndNewlines), !majorName.isEmpty {
            return majorName
        }
        if let fieldName = fieldName?.trimmingCharacters(in: .whitespacesAndNewlines), !fieldName.isEmpty {
            return fieldName
        }
        return communityName
    }

    var iconName: String {
        switch self {
        case .communityVerificationRequired:
            return "checkmark.shield.fill"
        case .specializationJoinRequired:
            return "person.badge.plus"
        case .joinRequiresVerificationFirst:
            return "lock.fill"
        }
    }

    func title(for actionType: LockedFeedActionType) -> String {
        switch self {
        case .communityVerificationRequired:
            return "Verify to \(actionType.verb.capitalized)"
        case .specializationJoinRequired:
            return "Join to \(actionType.verb.capitalized)"
        case .joinRequiresVerificationFirst:
            return "Verification Needed First"
        }
    }

    func body(for actionType: LockedFeedActionType) -> String {
        switch self {
        case .communityVerificationRequired(_, let communityName, _, _, _, _, _):
            return "Verify in \(communityName) to \(actionType.verb)."

        case .specializationJoinRequired(_, _, _, _, let joinCreditsRemaining, _):
            if let joinCreditsRemaining {
                if joinCreditsRemaining > 0 {
                    return "Join \(specializationDisplayName) to \(actionType.verb). You have \(joinCreditsRemaining) joins left."
                }
                return "Join \(specializationDisplayName) to \(actionType.verb), but you have no joins left right now."
            }
            return "Join \(specializationDisplayName) to \(actionType.verb)."

        case .joinRequiresVerificationFirst(_, _, _, _, _, _, let requiredKind, _, let verifyTargetCommunityName):
            let kindText = requiredKind?.displayName ?? "company or school"
            if let verifyTargetCommunityName, !verifyTargetCommunityName.isEmpty {
                return "To join \(specializationDisplayName), verify \(verifyTargetCommunityName) first. Then you can \(actionType.verb)."
            }
            return "To join \(specializationDisplayName), verify a \(kindText.lowercased()) first. Then you can \(actionType.verb)."
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .communityVerificationRequired(_, let communityName, _, _, _, _, let communityButtonShortName):
            let resolvedButtonName: String
            if let shortName = communityButtonShortName?.trimmingCharacters(in: .whitespacesAndNewlines), !shortName.isEmpty {
                resolvedButtonName = shortName
            } else {
                resolvedButtonName = communityName
            }
            return "Verify \(resolvedButtonName)"
        case .specializationJoinRequired:
            return "Join \(specializationDisplayName)"
        case .joinRequiresVerificationFirst(_, _, _, _, _, _, let requiredKind, _, let verifyTargetCommunityName):
            if let verifyTargetCommunityName, !verifyTargetCommunityName.isEmpty {
                return "Verify \(verifyTargetCommunityName)"
            }
            if let requiredKind {
                return "Verify \(requiredKind.displayName) to Join \(specializationDisplayName)"
            }
            return "Verify to Join \(specializationDisplayName)"
        }
    }

    var secondaryButtonTitle: String {
        "Not now"
    }

    var compactPrimaryButtonTitle: String {
        switch self {
        case .communityVerificationRequired:
            return "Verify"
        case .specializationJoinRequired:
            return "Join"
        case .joinRequiresVerificationFirst:
            return "Verify"
        }
    }

    func compactToastMessage(for actionType: LockedFeedActionType) -> String {
        switch self {
        case .communityVerificationRequired(_, let communityName, _, _, _, _, _):
            return "Locked in \(communityName): verify to \(actionType.verb)."
        case .specializationJoinRequired:
            return "Locked: join \(specializationDisplayName) to \(actionType.verb)."
        case .joinRequiresVerificationFirst(_, _, _, _, _, _, let requiredKind, _, let verifyTargetCommunityName):
            if let verifyTargetCommunityName, !verifyTargetCommunityName.isEmpty {
                return "Locked: verify \(verifyTargetCommunityName) before joining."
            }
            if let requiredKind {
                return "Locked: verify a \(requiredKind.displayName.lowercased()) before joining."
            }
            return "Locked: verification is required before joining."
        }
    }
}
