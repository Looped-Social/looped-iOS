import Foundation

struct UserFollowListResponseDTO: Decodable {
    let items: [UserFollowListItemDTO]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case followers
        case following
        case nextCursor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let decoded = try? container.decode([UserFollowListItemDTO].self, forKey: .items) {
            items = decoded
        } else if let decoded = try? container.decode([UserFollowListItemDTO].self, forKey: .followers) {
            items = decoded
        } else if let decoded = try? container.decode([UserFollowListItemDTO].self, forKey: .following) {
            items = decoded
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.items,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Missing items"
                )
            )
        }

        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

enum UserFollowListItemKindDTO: String, Decodable {
    case user
    case anon
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "user":
            self = .user
        case "anon", "anonymous", "anon_profile", "anonprofile":
            self = .anon
        default:
            self = .unknown
        }
    }
}

struct UserFollowListItemDTO: Decodable {
    let principalId: Int?
    let kind: UserFollowListItemKindDTO
    let userId: Int?
    let anonProfileId: Int?
    let id: Int
    let handle: String
    let displayName: String?
    let profileImageUrl: String?
    let companyId: Int?
    let isAnonymous: Bool?

    private enum CodingKeys: String, CodingKey {
        case principalId
        case kind
        case userId
        case anonProfileId
        case id
        case handle
        case displayName
        case profileImageUrl
        case companyId
        case isAnonymous
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        principalId = try container.decodeIfPresent(Int.self, forKey: .principalId)
        kind = (try? container.decode(UserFollowListItemKindDTO.self, forKey: .kind)) ?? .unknown
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        anonProfileId = try container.decodeIfPresent(Int.self, forKey: .anonProfileId)

        if let resolvedId = try container.decodeIfPresent(Int.self, forKey: .id) ?? userId ?? anonProfileId {
            id = resolvedId
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Missing id/user_id/anon_profile_id"
                )
            )
        }

        handle = (try? container.decode(String.self, forKey: .handle)) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        companyId = try container.decodeIfPresent(Int.self, forKey: .companyId)
        isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous)
    }
}
