import Foundation

struct BlockedUser: Identifiable {
    let id: UUID
    let backendId: Int
    let principalId: Int
    let kind: String?
    let handle: String
    let displayName: String?
    let profileImageURL: String?
    let companyId: Int
    let isAnonymous: Bool

    init(dto: BlockedUserDTO) {
        id = UUID.fromBackendId(dto.principalId)
        backendId = dto.id
        principalId = dto.principalId
        kind = dto.kind
        handle = dto.handle
        displayName = dto.displayName
        profileImageURL = dto.profileImageUrl
        companyId = dto.companyId
        if let kind = dto.kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            switch kind {
            case "anon":
                isAnonymous = true
            case "user":
                isAnonymous = false
            default:
                isAnonymous = dto.isAnonymous ?? false
            }
        } else {
            isAnonymous = dto.isAnonymous ?? false
        }
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
