import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let backendId: Int
    let username: String?
    let displayName: String?
    let handle: String
    let companyId: Int
    let companyName: String?
    let bio: String?
    let profileImageURL: String?
    let isVerified: Bool
    let isAnonymous: Bool
    let createdAt: Date?
    let updatedAt: Date?
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let commentsCount: Int?
    
    init(
        id: UUID,
        backendId: Int,
        username: String?,
        displayName: String?,
        handle: String,
        companyId: Int,
        companyName: String?,
        bio: String?,
        profileImageURL: String?,
        isVerified: Bool,
        isAnonymous: Bool,
        createdAt: Date?,
        updatedAt: Date?,
        followerCount: Int? = nil,
        followingCount: Int? = nil,
        postsCount: Int? = nil,
        commentsCount: Int? = nil
    ) {
        self.id = id
        self.backendId = backendId
        self.username = username
        self.displayName = displayName
        self.handle = handle
        self.companyId = companyId
        self.companyName = companyName
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.isVerified = isVerified
        self.isAnonymous = isAnonymous
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.postsCount = postsCount
        self.commentsCount = commentsCount
    }
}

extension User {
    init(dto: UserDTO, profile: UserProfileDTO?) {
        let stats = dto.stats
        self.id = UUID.fromBackendId(dto.id)
        self.backendId = dto.id
        self.username = profile?.username
        self.displayName = profile?.displayName
        self.handle = dto.handle
        self.companyId = dto.companyId
        self.companyName = nil
        self.bio = profile?.bio
        self.profileImageURL = profile?.profileImageUrl ?? dto.profileImageUrl
        self.isVerified = dto.verification?.verified ?? false
        self.isAnonymous = false
        self.createdAt = profile?.createdAt ?? dto.createdAt
        self.updatedAt = profile?.updatedAt ?? dto.updatedAt
        self.followerCount = stats?.followerCount ?? profile?.followerCount
        self.followingCount = stats?.followingCount ?? profile?.followingCount
        self.postsCount = stats?.postsCount ?? profile?.postsCount
        self.commentsCount = stats?.commentsCount ?? profile?.commentsCount
    }

    init(
        id: UUID,
        username: String?,
        displayName: String?,
        handle: String,
        company: String,
        bio: String?,
        profileImageURL: String?,
        isVerified: Bool,
        isAnonymous: Bool,
        createdAt: Date?,
        updatedAt: Date?,
        followerCount: Int? = nil,
        followingCount: Int? = nil,
        postsCount: Int? = nil,
        commentsCount: Int? = nil
    ) {
        self.init(
            id: id,
            backendId: 0,
            username: username,
            displayName: displayName,
            handle: handle,
            companyId: 0,
            companyName: company,
            bio: bio,
            profileImageURL: profileImageURL,
            isVerified: isVerified,
            isAnonymous: isAnonymous,
            createdAt: createdAt,
            updatedAt: updatedAt,
            followerCount: followerCount,
            followingCount: followingCount,
            postsCount: postsCount,
            commentsCount: commentsCount
        )
    }

    var company: String {
        companyName ?? "Looped"
    }
}
