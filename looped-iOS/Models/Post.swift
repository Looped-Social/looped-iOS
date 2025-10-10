import Foundation

struct Post: Codable, Identifiable {
    let id: UUID
    let content: String
    let authorId: UUID
    let authorDisplayName: String?
    let company: String
    let isAnonymous: Bool
    let reactionCount: Int
    let userReaction: ReactionType?
    let attachments: [MediaAttachment]?
    let createdAt: Date
    let updatedAt: Date
}

enum ReactionType: String, Codable, CaseIterable {
    case like = "like"
    case love = "love"
    case laugh = "laugh"
    case wow = "wow"
    case sad = "sad"
    case angry = "angry"
}