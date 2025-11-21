import Foundation

struct IdentityResponseDTO: Codable {
    let sub: String
    let iss: String
    let aud: [String]
    let email: String?
    let provisioned: Bool
    let user: UserDTO?
}

struct UserDTO: Codable {
    let id: Int
    let handle: String
    let companyId: Int
    let verification: VerificationDTO?
    let profile: UserProfileDTO?
}

struct VerificationDTO: Codable {
    let method: String
    let verified: Bool
    let verifiedAt: Date?
}

struct UserProfileDTO: Codable {
    let displayName: String?
    let username: String?
    let bio: String?
    let createdAt: Date?
    let updatedAt: Date?
    let profileImageUrl: String?
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let commentsCount: Int?
}
