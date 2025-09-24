import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let username: String
    let displayName: String?
    let handle: String // @handle format
    let company: String
    let jobTitle: String
    let bio: String?
    let profileImageURL: String?
    let isVerified: Bool
    let isAnonymous: Bool
    let yearsInLoop: Int
    let followingCount: Int
    let followersCount: Int
    let postsCount: Int
    let commentsCount: Int
    let isCurrentUser: Bool
    let createdAt: Date
    let updatedAt: Date

    // Computed properties for display
    var formattedHandle: String {
        return "@\(handle)"
    }

    var formattedYearsInLoop: String {
        return "\(yearsInLoop) year\(yearsInLoop == 1 ? "" : "s") in the Loop"
    }

    var formattedJobTitle: String {
        return "\(jobTitle) @ \(company)"
    }
}