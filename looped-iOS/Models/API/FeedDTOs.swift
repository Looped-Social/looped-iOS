import Foundation

struct FeedResponseDTO: Codable {
    let items: [PostDTO]
    let nextCursor: String?
}

struct TrendingFeedResponseDTO: Codable {
    let items: [TrendingPostDTO]
}

struct TrendingPostDTO: Codable {
    let id: Int
    let authorId: Int?
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
    let repostCount: Int
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
