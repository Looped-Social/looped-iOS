import Foundation

struct CommentListResponseDTO: Codable {
    let items: [CommentDTO]
    let nextCursor: String?
}

struct CommentDTO: Codable {
    let id: Int
    let postId: Int
    let parentId: Int?
    let author: CommentAuthorDTO
    let isAnonymous: Bool?
    let authorIsAnonymous: Bool?
    let authorPrincipalId: Int?
    let content: String
    let mediaAssetId: Int?
    let likesCount: Int
    let replyCount: Int?
    let userLiked: Bool?
    let likedByCreator: Bool?
    let isDeleted: Bool?
    let createdAt: Date
}

struct CommentAuthorDTO: Codable {
    let id: Int
    let principalId: Int?
    let isAnonymous: Bool?
    let displayName: String?
    let username: String?
    let handle: String?
    let companyId: Int?
    let profileImageUrl: String?
}

struct CreateCommentRequestDTO: Codable {
    let content: String
    let parentId: Int?
    let mediaAssetId: Int?
    let asAnon: Bool?
    let anonProfileId: Int?
    let anonCert: String?
    let anonCertKid: String?
    let anonSig: String?
}

struct EditCommentRequestDTO: Codable {
    let content: String
    let asAnon: Bool?
    let anonProfileId: Int?
    let anonCert: String?
    let anonCertKid: String?
    let anonSig: String?
}

struct CommentLikeRequestDTO: Codable {
    let asAnon: Bool?
    let anonProfileId: Int?
    let anonCert: String?
    let anonCertKid: String?
    let anonSig: String?
}

struct CommentDeleteRequestDTO: Codable {
    let asAnon: Bool?
    let anonProfileId: Int?
    let anonCert: String?
    let anonCertKid: String?
    let anonSig: String?
}

struct CommentLikeResponseDTO: Codable {
    let commentId: Int
    let likesCount: Int
    let userLiked: Bool?
    let likedByCreator: Bool?
}

struct CommentDeleteResponseDTO: Codable {
    let id: Int
    let deleted: Bool
}
