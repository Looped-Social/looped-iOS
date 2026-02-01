import Foundation

enum UserFollowListItemKind: String {
    case user
    case anon
}

struct UserFollowListItem: Identifiable {
    let id: Int
    let principalId: Int
    let kind: UserFollowListItemKind
    let entityId: Int
    let handle: String
    let displayName: String?
    let profileImageURL: String?
    let companyId: Int
    let isAnonymous: Bool

    init(dto: UserFollowListItemDTO) {
        let resolvedEntityId = dto.userId ?? dto.anonProfileId ?? dto.id
        let resolvedKind: UserFollowListItemKind = {
            switch dto.kind {
            case .user:
                return .user
            case .anon:
                return .anon
            case .unknown:
                if dto.anonProfileId != nil { return .anon }
                if dto.isAnonymous == true { return .anon }
                return .user
            }
        }()
        let fallbackPrincipalId = resolvedKind == .anon ? -resolvedEntityId : resolvedEntityId

        principalId = dto.principalId ?? fallbackPrincipalId
        id = principalId
        kind = resolvedKind
        entityId = resolvedEntityId
        handle = dto.handle
        displayName = dto.displayName
        profileImageURL = dto.profileImageUrl
        companyId = dto.companyId ?? 0
        isAnonymous = dto.isAnonymous ?? (resolvedKind == .anon)
    }

    var resolvedDisplayName: String {
        let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let handleTrimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        return handleTrimmed.isEmpty ? "Looped User" : handleTrimmed
    }

    var formattedHandle: String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "looped" : trimmed
        return "@\(resolved)"
    }

    var titleText: String {
        switch kind {
        case .user:
            return resolvedDisplayName
        case .anon:
            return formattedHandle
        }
    }

    var subtitleText: String {
        switch kind {
        case .user:
            return formattedHandle
        case .anon:
            return "Anonymous profile"
        }
    }
}

struct UserFollowListPage {
    let items: [UserFollowListItem]
    let nextCursor: String?
}
