import Foundation

struct AnonProfile: Codable, Identifiable {
    let id: Int
    let handle: String
    let companyId: Int?
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let createdAt: Date?
    let updatedAt: Date?
    let displayCommunity: DisplayCommunity?

    var formattedHandle: String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        return "@\(trimmed.isEmpty ? "anonymous" : trimmed)"
    }
}

extension AnonProfile {
    init(dto: AnonProfileDTO) {
        id = dto.id
        handle = dto.handle
        companyId = dto.companyId
        followerCount = dto.stats?.followerCount
        followingCount = dto.stats?.followingCount
        postsCount = dto.stats?.postsCount
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
        displayCommunity = dto.displayCommunity.map(DisplayCommunity.init(dto:))
    }

    func asUserProfile(companyName: String?, isCurrentUser: Bool = true) -> UserProfile {
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
            isCurrentUser: isCurrentUser,
            displayCommunity: displayCommunity,
            displaySpecialization: nil,
            createdAt: createdAt,
            updatedAt: updatedAt ?? now
        )
    }
}
