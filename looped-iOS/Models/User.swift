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
}

extension User {
    init(dto: UserDTO, profile: UserProfileDTO?) {
        self.init(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            username: profile?.username,
            displayName: profile?.displayName,
            handle: dto.handle,
            companyId: dto.companyId,
            companyName: nil,
            bio: profile?.bio,
            profileImageURL: nil,
            isVerified: dto.verification?.verified ?? false,
            isAnonymous: false,
            createdAt: profile?.createdAt,
            updatedAt: profile?.updatedAt
        )
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
        updatedAt: Date?
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
            updatedAt: updatedAt
        )
    }
    
    var company: String {
        companyName ?? "Looped"
    }
}
