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

    var formattedHandle: String {
        "@\(handle)"
    }

    var formattedYearsInLoop: String {
        "\(yearsInLoop) year\(yearsInLoop == 1 ? "" : "s") in the Loop"
    }

    var formattedJobTitle: String {
        "\(jobTitle) @ \(company)"
    }
}

extension UserProfile {
    static func from(user: User) -> UserProfile {
        UserProfile(
            id: user.id,
            username: user.username ?? user.handle,
            displayName: user.displayName ?? "Looped User",
            handle: user.handle,
            company: user.companyName ?? "Looped",
            jobTitle: "Team Member",
            bio: user.bio,
            profileImageURL: user.profileImageURL,
            isVerified: user.isVerified,
            isAnonymous: user.isAnonymous,
            yearsInLoop: 1,
            followingCount: 0,
            followersCount: 0,
            postsCount: 0,
            commentsCount: 0,
            isCurrentUser: true,
            createdAt: user.createdAt ?? Date(),
            updatedAt: user.updatedAt ?? Date()
        )
    }
}
