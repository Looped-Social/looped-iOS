import Foundation

struct FeedResponseDTO: Codable {
    let feedRequestId: String?
    let items: [PostDTO]
    let nextCursor: String?
}

struct TrendingFeedResponseDTO: Codable {
    let items: [TrendingPostDTO]
}

struct TrendingPostDTO: Codable {
    let id: Int
    let authorId: Int?
    let authorDisplayName: String?
    let authorFirstName: String?
    let authorLastName: String?
    let authorHandle: String?
    let authorProfileImageUrl: String?
    let authorIsAnonymous: Bool?
    let companyId: Int
    let communityId: Int?
    let content: String
    let mediaAssetId: Int?
    let mediaAssetIds: [Int]?
    let mediaAssetIdsSnake: [Int]?
    let likesCount: Int
    let commentsCount: Int?
    let shareCount: Int?
    let userLiked: Bool?
    let createdAt: Date
    let isSaved: Bool?
    let isAnonymous: Bool?
    let communityName: String?
    let communityShortName: String?
    let communityKind: String?
    let title: String?
    let mediaUrl: String?
    let cdnUrl: String?
    let authorDisplayCommunity: DisplayCommunityDTO?
    let authorDisplaySpecialization: DisplayCommunityDTO?
}

struct PostDTO: Codable {
    let id: Int
    let fypRank: Int?
    let fypSourcePool: String?
    let authorId: Int?
    let authorHandle: String?
    let authorDisplayName: String?
    let authorFirstName: String?
    let authorLastName: String?
    let authorProfileImageUrl: String?
    let authorIsAnonymous: Bool?
    let authorPrincipalId: Int?
    let anonProfileId: Int?
    let companyId: Int?
    let communityId: Int?
    let communityName: String?
    let communityShortName: String?
    let communityKind: String?
    let content: String
    let mediaAssetId: Int?
    let mediaAssetIds: [Int]?
    let mediaAssetIdsSnake: [Int]?
    let mediaUrl: String?
    let cdnUrl: String?
    let likesCount: Int?
    let userLiked: Bool?
    let commentsCount: Int?
    let shareCount: Int?
    let repostCount: Int?
    let viewerHasReposted: Bool?
    let repostedByFollowedUsers: [RepostedByUserDTO]?
    let repostedByFollowedUsersCount: Int?
    let createdAt: Date
    let isSaved: Bool?
    let isAnonymous: Bool?
    let authorDisplayCommunity: DisplayCommunityDTO?
    let authorDisplaySpecialization: DisplayCommunityDTO?
    let poll: PollDTO?
    let isUnderReview: Bool?
    let viewerCapabilities: PostViewerCapabilitiesDTO?
}

struct PostViewerCapabilitiesDTO: Codable {
    let canInteract: Bool?
    let canPost: Bool?
    let canComment: Bool?
    let canReply: Bool?
    let canLike: Bool?
    let canVote: Bool?
    let canRepost: Bool?
    let canSave: Bool?
    let lockReason: String?
    let requiresVerification: Bool?
    let requiresJoin: Bool?
    let lockContext: PostViewerLockContextDTO?
    let primaryUnlockAction: PostViewerPrimaryUnlockActionDTO?
}

struct PostViewerLockContextDTO: Codable {
    let communityId: Int?
    let communityName: String?
    let communityKind: String?
    let specializationId: Int?
    let specializationName: String?
    let specializationType: String?
    let joinCreditsRemaining: Int?
    let joinCreditsLimit: Int?
    let joinCooldownActive: Bool?
    let joinCooldownEndsAt: Date?
    let requiredVerificationKind: String?
    let verifyTargetCommunityId: Int?
    let verifyTargetCommunityName: String?
    let alreadyVerifiedElsewhere: Bool?
}

struct PostViewerPrimaryUnlockActionDTO: Codable {
    let type: String?
    let communityId: Int?
    let specializationId: Int?
    let label: String?
}

struct RepostedByUserDTO: Codable {
    let userId: Int
    let username: String
}

struct CreatePostResponseDTO: Codable {
    let id: Int
}

struct CreatePostRequestDTO: Codable {
    let content: String
    let mediaAssetId: Int?
    let mediaAssetIds: [Int]?
    let communityId: Int
    let isAnon: Bool?
    let anonProfileId: Int?
    let anonCert: String?
    let anonCertKid: String?
    let anonSig: String?
    let anonCompanyId: Int?
    let anonTimestamp: Int?
    let poll: CreatePostPollRequestDTO?
}

struct UpdatePostRequestDTO: Codable {
    let content: String
    let asAnon: Bool?
    let anonProfileId: Int?
    let anonCert: String?
    let anonCertKid: String?
    let anonSig: String?
}

struct PostLikeResponseDTO: Codable {
    let postId: Int
    let likesCount: Int
}

struct PostSaveResponseDTO: Codable {
    let postId: Int
    let saved: Bool
}

struct PostShareResponseDTO: Codable {
    let postId: Int
    let shareCount: Int
}

struct PostRepostResponseDTO: Codable {
    let postId: Int
    let viewerHasReposted: Bool
}

struct PostDeleteResponseDTO: Codable {
    let id: Int
    let deleted: Bool
}

struct AnonActionRequestDTO: Codable {
    let asAnon: Bool
    let anonProfileId: Int
    let anonCert: String
    let anonCertKid: String
    let anonSig: String
}
