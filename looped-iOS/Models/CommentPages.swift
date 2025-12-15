import Foundation

struct CommentPage {
    let comments: [Comment]
    let nextCursor: String?
}

struct CommentLikeResponse {
    let commentId: Int
    let likesCount: Int
    let userLiked: Bool
    let likedByCreator: Bool
}
