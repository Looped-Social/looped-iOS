import Foundation

struct AnonProfile: Codable, Identifiable {
    let id: Int
    let handle: String
    let companyId: Int
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let createdAt: Date?
    let updatedAt: Date?

    var formattedHandle: String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        return "@\(trimmed.isEmpty ? "anonymous" : trimmed)"
    }
}

extension AnonProfile {
    func asUserProfile(companyName: String?) -> UserProfile {
        let now = Date()
        let createdAt = createdAt ?? now
        let calendar = Calendar.current
        let yearsInLoop = max(0, calendar.component(.year, from: now) - calendar.component(.year, from: createdAt))

        return UserProfile(
            id: UUID.fromBackendId(id),
            backendId: id,
            username: handle,
            displayName: "Anonymous",
            handle: handle,
            company: companyName ?? "Looped",
            jobTitle: "Team Member",
            bio: nil,
            profileImageURL: nil,
            isVerified: false,
            isAnonymous: true,
            yearsInLoop: yearsInLoop,
            followingCount: followingCount ?? 0,
            followersCount: followerCount ?? 0,
            postsCount: postsCount ?? 0,
            commentsCount: 0,
            showFollowerCount: false,
            isCurrentUser: true,
            displayCommunity: nil,
            createdAt: createdAt,
            updatedAt: updatedAt ?? now
        )
    }
}
