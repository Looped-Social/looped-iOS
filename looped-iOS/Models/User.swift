import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let username: String
    let displayName: String?
    let company: String
    let isVerified: Bool
    let isAnonymous: Bool
    let createdAt: Date
    let updatedAt: Date
}