import Foundation

struct BlockedUsersResponseDTO: Codable {
    let items: [BlockedUserDTO]
    let nextCursor: String?
}

struct BlockedUserDTO: Codable {
    let principalId: Int
    let id: Int
    let kind: String?
    let handle: String
    let displayName: String?
    let profileImageUrl: String?
    let companyId: Int
    let isAnonymous: Bool?
}

struct BlockActionResponseDTO: Codable {
    let userId: Int
    let blocked: Bool
}

struct PrincipalBlockActionResponseDTO: Codable {
    let principalId: Int
    let blocked: Bool
}
