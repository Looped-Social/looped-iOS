import Foundation

struct UserSearchResponseDTO: Codable {
    let items: [UserSearchDTO]
    let nextCursor: String?
}

struct UserSearchDTO: Codable {
    let id: Int
    let handle: String
    let username: String?
    let displayName: String?
    let bio: String?
    let companyId: Int
    let profileImageUrl: String?
}
