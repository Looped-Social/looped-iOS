import Foundation

struct UserContentPage {
    let items: [UserContentItem]
    let nextCursor: String?
}

struct UserContentReply: Identifiable {
    let id: Int
    let postId: Int
    let content: String
    let createdAt: Date
    let isDeleted: Bool
    let parentId: Int?

    init(dto: UserContentReplyDTO) {
        self.id = dto.id
        self.postId = dto.postId
        self.content = dto.content
        self.createdAt = dto.createdAt
        self.isDeleted = dto.isDeleted ?? false
        self.parentId = dto.parentId
    }
}

enum UserContentItemPayload {
    case post(Post)
    case reply(UserContentReply)
}

struct UserContentItem: Identifiable {
    let id: String
    let createdAt: Date
    let payload: UserContentItemPayload

    init(id: String, createdAt: Date, payload: UserContentItemPayload) {
        self.id = id
        self.createdAt = createdAt
        self.payload = payload
    }

    init?(dto: UserContentItemDTO) {
        switch dto.type.lowercased() {
        case "post":
            guard let postDTO = dto.post else { return nil }
            let post = Post(dto: postDTO)
            let postId = post.backendId.map(String.init) ?? post.id.uuidString
            self.init(id: "post-\(postId)", createdAt: dto.createdAt, payload: .post(post))
        case "reply":
            guard let replyDTO = dto.reply else { return nil }
            let reply = UserContentReply(dto: replyDTO)
            self.init(id: "reply-\(reply.id)", createdAt: dto.createdAt, payload: .reply(reply))
        default:
            return nil
        }
    }
}
