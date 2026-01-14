import Foundation

struct IdentityResponseDTO: Codable {
    let sub: String
    let iss: String
    let aud: [String]
    let email: String?
    let provisioned: Bool
    let user: UserDTO?
    let onboardingComplete: Bool?
    let onboardingStep: RemoteOnboardingStep?
}

struct UserDTO: Codable {
    let id: Int
    let handle: String
    let username: String?
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let dateOfBirth: String?
    let companyId: Int
    let bio: String?
    let verification: VerificationDTO?
    let profile: UserProfileDTO?
    let stats: UserStatsDTO?
    let displayCommunity: DisplayCommunityDTO?
    let displaySpecialization: DisplayCommunityDTO?
    let profileImageUrl: String?
    let showFollowerCount: Bool?
    let hideAnonymousPosts: Bool?
    let messagePermission: MessagePermission?
    let createdAt: Date?
    let updatedAt: Date?
}

struct VerificationDTO: Codable {
    let method: String
    let verified: Bool
    let verifiedAt: Date?
}

struct UserProfileDTO: Codable {
    let displayName: String?
    let username: String?
    let firstName: String?
    let lastName: String?
    let dateOfBirth: String?
    let bio: String?
    let createdAt: Date?
    let updatedAt: Date?
    let profileImageUrl: String?
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let commentsCount: Int?
    let showFollowerCount: Bool?
    let messagePermission: MessagePermission?
}

struct UserStatsDTO: Codable {
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let commentsCount: Int?
}

struct UserFollowRequestDTO: Encodable {
    let asAnon: Bool?
}

struct UserFollowActionResponseDTO: Decodable {
    let userId: Int
    let following: Bool
}
