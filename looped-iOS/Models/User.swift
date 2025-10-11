import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let username: String
    let displayName: String?
    let handle: String
    let company: String
    let bio: String?
    let profileImageURL: String?
    let isVerified: Bool
    let isAnonymous: Bool
    let createdAt: Date
    let updatedAt: Date
}