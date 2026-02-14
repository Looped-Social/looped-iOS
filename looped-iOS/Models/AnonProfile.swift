import Foundation

struct AnonProfile: Codable, Identifiable {
    let id: Int
    let handle: String
    let companyId: Int?
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let showFollowerCount: Bool?
    let createdAt: Date?
    let updatedAt: Date?
    let displayCommunity: DisplayCommunity?
    let displaySpecialization: DisplayCommunity?

    var formattedHandle: String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        return "@\(trimmed.isEmpty ? "anonymous" : trimmed)"
    }
}

extension AnonProfile {
    init(dto: AnonProfileDTO) {
        let resolvedHandle = Self.preferredHandle(handle: dto.handle, username: dto.username)
        id = dto.id
        handle = resolvedHandle
        companyId = dto.companyId
        followerCount = dto.stats?.followerCount
        followingCount = dto.stats?.followingCount
        postsCount = dto.stats?.postsCount
        showFollowerCount = dto.showFollowerCount
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
        displayCommunity = dto.displayCommunity.map(DisplayCommunity.init(dto:))
        displaySpecialization = dto.displaySpecialization.map(DisplayCommunity.init(dto:))
    }

    func asUserProfile(companyName: String?, isCurrentUser: Bool = true) -> UserProfile {
        let now = Date()
        let createdAt = createdAt ?? now
        let calendar = Calendar.current
        let yearsInLoop = max(0, calendar.component(.year, from: now) - calendar.component(.year, from: createdAt))
        let resolvedHandle = Self.preferredHandle(handle: handle, username: nil)

        return UserProfile(
            id: UUID.fromBackendId(id),
            backendId: id,
            username: resolvedHandle,
            displayName: resolvedHandle,
            handle: resolvedHandle,
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
            showFollowerCount: showFollowerCount ?? true,
            isCurrentUser: isCurrentUser,
            displayCommunity: displayCommunity,
            displaySpecialization: displaySpecialization,
            createdAt: createdAt,
            updatedAt: updatedAt ?? now
        )
    }

    private static func preferredHandle(handle: String?, username: String?) -> String {
        let trimmedHandle = (handle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHandle.isEmpty {
            return trimmedHandle
        }
        let trimmedUsername = (username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUsername.isEmpty {
            return trimmedUsername
        }
        return "anonymous"
    }
}
