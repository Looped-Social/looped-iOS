import Foundation

struct BlockedUser: Identifiable {
    let id: UUID
    let backendId: Int
    let principalId: Int
    let handle: String
    let displayName: String?
    let profileImageURL: String?
    let companyId: Int
    let isAnonymous: Bool

    init(dto: BlockedUserDTO) {
        id = UUID.fromBackendId(dto.id)
        backendId = dto.id
        principalId = dto.principalId
        handle = dto.handle
        displayName = dto.displayName
        profileImageURL = dto.profileImageUrl
        companyId = dto.companyId
        isAnonymous = dto.isAnonymous
    }

    var resolvedDisplayName: String {
        let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Looped User" : trimmed
    }

    var formattedHandle: String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "looped" : trimmed
        return "@\(resolved)"
    }

    var subtitle: String {
        isAnonymous ? "Anonymous account" : formattedHandle
    }
}
