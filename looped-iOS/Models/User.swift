import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let backendId: Int
    let username: String?
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let dateOfBirth: String?
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
    let showFollowerCount: Bool?
    let messagePermission: MessagePermission?
    let displayCommunity: DisplayCommunity?
    let displaySpecialization: DisplayCommunity?
    
    init(
        id: UUID,
        backendId: Int,
        username: String?,
        displayName: String?,
        firstName: String? = nil,
        lastName: String? = nil,
        dateOfBirth: String? = nil,
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
        commentsCount: Int? = nil,
        showFollowerCount: Bool? = nil,
        messagePermission: MessagePermission? = nil,
        displayCommunity: DisplayCommunity? = nil,
        displaySpecialization: DisplayCommunity? = nil
    ) {
        self.id = id
        self.backendId = backendId
        self.username = username
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
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
        self.showFollowerCount = showFollowerCount
        self.messagePermission = messagePermission
        self.displayCommunity = displayCommunity
        self.displaySpecialization = displaySpecialization
    }
}

extension User {
    init(dto: UserDTO, profile: UserProfileDTO?) {
        let stats = dto.stats
        let resolvedFirstName = dto.firstName ?? profile?.firstName
        let resolvedLastName = dto.lastName ?? profile?.lastName
        let resolvedFullName = [resolvedFirstName, resolvedLastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        self.id = UUID.fromBackendId(dto.id)
        self.backendId = dto.id
        self.username = dto.username ?? profile?.username
        self.displayName = dto.displayName ?? profile?.displayName ?? (resolvedFullName.isEmpty ? nil : resolvedFullName)
        self.firstName = resolvedFirstName
        self.lastName = resolvedLastName
        self.dateOfBirth = dto.dateOfBirth ?? profile?.dateOfBirth
        self.handle = dto.handle
        self.companyId = dto.companyId
        self.companyName = nil
        self.bio = profile?.bio ?? dto.bio
        self.profileImageURL = profile?.profileImageUrl ?? dto.profileImageUrl
        self.isVerified = dto.verification?.verified ?? false
        self.isAnonymous = false
        self.createdAt = profile?.createdAt ?? dto.createdAt
        self.updatedAt = profile?.updatedAt ?? dto.updatedAt
        self.followerCount = stats?.followerCount ?? profile?.followerCount
        self.followingCount = stats?.followingCount ?? profile?.followingCount
        self.postsCount = stats?.postsCount ?? profile?.postsCount
        self.commentsCount = stats?.commentsCount ?? profile?.commentsCount
        self.showFollowerCount = profile?.showFollowerCount ?? dto.showFollowerCount
        self.messagePermission = dto.messagePermission ?? profile?.messagePermission
        self.displayCommunity = dto.displayCommunity.map(DisplayCommunity.init(dto:))
        self.displaySpecialization = dto.displaySpecialization.map(DisplayCommunity.init(dto:))
    }

    init(
        id: UUID,
        username: String?,
        displayName: String?,
        firstName: String? = nil,
        lastName: String? = nil,
        dateOfBirth: String? = nil,
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
        commentsCount: Int? = nil,
        showFollowerCount: Bool? = nil,
        messagePermission: MessagePermission? = nil,
        displayCommunity: DisplayCommunity? = nil,
        displaySpecialization: DisplayCommunity? = nil
    ) {
        self.init(
            id: id,
            backendId: 0,
            username: username,
            displayName: displayName,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
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
            commentsCount: commentsCount,
            showFollowerCount: showFollowerCount,
            messagePermission: messagePermission,
            displayCommunity: displayCommunity,
            displaySpecialization: displaySpecialization
        )
    }

    var company: String {
        companyName ?? "Looped"
    }
}
