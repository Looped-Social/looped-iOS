import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let backendId: Int?
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
    let showFollowerCount: Bool
    let isCurrentUser: Bool
    let createdAt: Date
    let updatedAt: Date

    var formattedHandle: String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        return "@\(trimmed.isEmpty ? "looped" : trimmed)"
    }

    var formattedYearsInLoop: String {
        "\(yearsInLoop) year\(yearsInLoop == 1 ? "" : "s") in the Loop"
    }

    var formattedJobTitle: String {
        "\(resolvedJobTitle) @ \(resolvedCompany)"
    }

    var resolvedDisplayName: String {
        normalized(displayName, fallback: "Looped User")
    }

    var resolvedCompany: String {
        normalized(company, fallback: "Looped")
    }

    var resolvedJobTitle: String {
        normalized(jobTitle, fallback: "Team Member")
    }

    private func normalized(_ value: String?, fallback: String) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

extension UserProfile {
    static func from(user: User, isCurrentUser: Bool = false) -> UserProfile {
        let now = Date()
        let createdAt = user.createdAt ?? now
        let calendar = Calendar.current
        let yearsInLoop = max(0, calendar.component(.year, from: now) - calendar.component(.year, from: createdAt))

        return UserProfile(
            id: user.id,
            backendId: user.backendId,
            username: user.username ?? user.handle,
            displayName: user.displayName ?? "Looped User",
            handle: user.handle,
            company: user.companyName ?? "Looped",
            jobTitle: "Team Member",
            bio: user.bio,
            profileImageURL: user.profileImageURL,
            isVerified: user.isVerified,
            isAnonymous: user.isAnonymous,
            yearsInLoop: yearsInLoop,
            followingCount: user.followingCount ?? 0,
            followersCount: user.followerCount ?? 0,
            postsCount: user.postsCount ?? 0,
            commentsCount: user.commentsCount ?? 0,
            showFollowerCount: user.showFollowerCount ?? true,
            isCurrentUser: isCurrentUser,
            createdAt: createdAt,
            updatedAt: user.updatedAt ?? now
        )
    }
}
