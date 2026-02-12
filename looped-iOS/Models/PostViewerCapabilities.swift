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
}

enum PostViewerLockReason: String, Codable, Equatable {
    case communityNotVerified = "COMMUNITY_NOT_VERIFIED"
    case specializationNotJoined = "SPECIALIZATION_NOT_JOINED"
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
    }

    func lockTitle(for _: String) -> String {
        switch lockReason {
        case .some(.specializationNotJoined):
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
        case .some(.communityNotVerified):
            return "You must be verified in this community to \(verb). Verify in Settings → Community Verifications."
        case .some(.verificationExpired):
            return "Your verification expired. Verify again to \(verb)."
        case .some(.communityBanned):
            return "You can’t \(verb) in this community."
        case .some(.unknownRestriction), .none:
            return "You can’t \(verb) right now."
        }
    }
}
