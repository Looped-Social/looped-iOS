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
    let authorId: Int
    let companyId: Int
    let communityId: Int?
    let content: String
    let mediaAssetId: Int?
    let likesCount: Int
    let commentsCount: Int?
    let shareCount: Int?
    let createdAt: Date
    let isSaved: Bool?
    let isAnonymous: Bool?
    let communityName: String?
    let communityKind: String?
    let title: String?
    let mediaUrl: String?
    let cdnUrl: String?
    let authorDisplayCommunity: DisplayCommunityDTO?
}

struct PostDTO: Codable {
    let id: Int
    let authorId: Int
    let companyId: Int
    let communityId: Int?
    let communityName: String?
    let communityKind: String?
    let content: String
    let mediaAssetId: Int?
    let likesCount: Int
    let commentsCount: Int?
    let shareCount: Int?
    let createdAt: Date
    let isSaved: Bool?
    let isAnonymous: Bool?
    let authorDisplayCommunity: DisplayCommunityDTO?
}

struct CreatePostRequestDTO: Codable {
    let content: String
    let mediaAssetId: Int?
    let communityId: Int
    let isAnon: Bool?
    let anonProfileId: Int?
    let anonCert: String?
    let anonCertKid: String?
    let anonSig: String?
    let anonCompanyId: Int?
    let anonTimestamp: Int?
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
