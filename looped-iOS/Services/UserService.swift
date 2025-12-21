import Foundation

class UserService: UserServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func getIdentity() async throws -> IdentityResponseDTO {
        try await apiClient.get("/v1/me")
    }
    
    func getCurrentUser() async throws -> User {
        let identity = try await getIdentity()
        guard let userDTO = identity.user else {
            throw UserServiceError.userNotProvisioned
        }
        // /v1/me may omit follower/following stats; fetch full user if counts are missing
        let baseUser = User(dto: userDTO, profile: userDTO.profile)
        if baseUser.followerCount == nil || baseUser.followingCount == nil || baseUser.postsCount == nil || baseUser.commentsCount == nil {
            let fullDTO: UserDTO = try await apiClient.get("/v1/users/\(userDTO.id)")
            return User(dto: fullDTO, profile: fullDTO.profile)
        }
        return baseUser
    }
    
    func getUser(by id: Int) async throws -> User {
        let dto: UserDTO = try await apiClient.get("/v1/users/\(id)")
        return User(dto: dto, profile: dto.profile)
    }
    
    func updateProfile(displayName: String?, bio: String?, isAnonymous: Bool) async throws -> User {
        let request = UpdateProfileRequest(displayName: displayName, bio: bio, isAnonymous: isAnonymous)
        return try await apiClient.put("/users/me", body: request)
    }
    
    func deleteAccount(mode: DeleteAccountMode = .hard) async throws {
        try await apiClient.delete("/v1/users/me?mode=\(mode.rawValue)")
    }

    func verifyEmployment(verification: EmploymentVerification) async throws {
        let _: EmptyResponse = try await apiClient.post("/users/verify-employment", body: verification)
    }

    func searchUsers(query: String, limit: Int, cursor: String?) async throws -> UserSearchPage {
        var endpoint = "/v1/users/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=\(limit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: UserSearchResponseDTO = try await apiClient.get(endpoint)
        let users = response.items.map { dto in
            User(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                username: dto.username ?? dto.handle,
                displayName: dto.displayName,
                handle: dto.handle,
                companyId: dto.companyId,
                companyName: nil,
            bio: dto.bio,
            profileImageURL: dto.profileImageUrl,
            isVerified: false,
            isAnonymous: false,
            createdAt: nil,
            updatedAt: nil,
            followerCount: nil,
            followingCount: nil,
            postsCount: nil,
            commentsCount: nil
        )
    }
        return UserSearchPage(users: users, nextCursor: response.nextCursor)
    }

    func fetchUserComments(userId: Int, limit: Int, cursor: String?) async throws -> UserCommentsPage {
        var endpoint = "/v1/users/\(userId)/comments?limit=\(limit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: UserCommentsResponseDTO = try await apiClient.get(endpoint)
        let comments = response.items.map { dto in
            Comment(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                postId: UUID.fromBackendId(dto.postId),
                postBackendId: dto.postId,
                content: dto.content,
                authorId: UUID.fromBackendId(userId),
                authorBackendId: userId,
                company: "",
                createdAt: dto.createdAt,
                updatedAt: dto.createdAt,
                replyToCommentId: dto.parentId != nil ? UUID.fromBackendId(dto.parentId!) : nil
            )
        }
        return UserCommentsPage(comments: comments, nextCursor: response.nextCursor)
    }
}

enum UserServiceError: Error, LocalizedError {
    case userNotProvisioned
    
    var errorDescription: String? {
        switch self {
        case .userNotProvisioned:
            return "Your account isn't fully onboarded yet."
        }
    }
}

private struct UpdateProfileRequest: Codable {
    let displayName: String?
    let bio: String?
    let isAnonymous: Bool
}
