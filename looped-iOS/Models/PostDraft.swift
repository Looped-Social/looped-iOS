import Foundation

struct PostDraft: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    var communityId: Int?
    var communityName: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        content: String,
        communityId: Int? = nil,
        communityName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.communityId = communityId
        self.communityName = communityName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
