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
    let likesCount: Int
    let userLiked: Bool?
    let likedByCreator: Bool?
    let createdAt: Date
}

struct CommentAuthorDTO: Codable {
    let id: Int
    let principalId: Int?
    let displayName: String?
    let username: String?
    let handle: String?
    let companyId: Int?
    let profileImageUrl: String?
}

struct CreateCommentRequestDTO: Codable {
    let content: String
    let parentId: Int?
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

struct CommentLikeResponseDTO: Codable {
    let commentId: Int
    let likesCount: Int
    let userLiked: Bool?
    let likedByCreator: Bool?
}
