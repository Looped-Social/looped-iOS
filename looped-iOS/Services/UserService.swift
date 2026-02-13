import Foundation

class UserService: UserServiceProtocol {
    private let apiClient: APIClient
    private let anonService: AnonService
    
    init(apiClient: APIClient = APIClient(), anonService: AnonService = .shared) {
        self.apiClient = apiClient
        self.anonService = anonService
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
        if baseUser.followerCount == nil
            || baseUser.followingCount == nil
            || baseUser.postsCount == nil
            || baseUser.commentsCount == nil
            || baseUser.likesReceivedCount == nil
            || baseUser.showFollowerCount == nil {
            let fullDTO: UserDTO = try await apiClient.get("/v1/users/\(userDTO.id)")
            return User(dto: fullDTO, profile: fullDTO.profile)
        }
        return baseUser
    }
    
    func getUser(by id: Int) async throws -> User {
        let dto: UserDTO = try await apiClient.get("/v1/users/\(id)")
        return User(dto: dto, profile: dto.profile)
    }

    func followUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> UserFollowActionResult {
        if asAnonymousActor {
            let anonContext = try await anonService.actionContext(for: .followUser(userId: userId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: UserFollowActionResponseDTO = try await apiClient.post(
                "/v1/users/\(userId)/follow",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return UserFollowActionResult(userId: response.userId, following: response.following)
        }

        let request = UserFollowRequestDTO(asAnon: false)
        let response: UserFollowActionResponseDTO = try await apiClient.post("/v1/users/\(userId)/follow", body: request)
        return UserFollowActionResult(userId: response.userId, following: response.following)
    }

    func unfollowUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> UserFollowActionResult {
        if asAnonymousActor {
            let anonContext = try await anonService.actionContext(for: .unfollowUser(userId: userId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: UserFollowActionResponseDTO = try await apiClient.delete(
                "/v1/users/\(userId)/follow",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return UserFollowActionResult(userId: response.userId, following: response.following)
        }

        let request = UserFollowRequestDTO(asAnon: false)
        let response: UserFollowActionResponseDTO = try await apiClient.delete(
            "/v1/users/\(userId)/follow",
            body: request
        )
        return UserFollowActionResult(userId: response.userId, following: response.following)
    }

    func followAnonProfile(
        anonProfileId: Int,
        asAnonymousActor: Bool,
        communityId: Int?
    ) async throws -> AnonProfileFollowActionResult {
        if asAnonymousActor {
            let anonContext = try await anonService.actionContext(
                for: .followAnonProfile(anonProfileId: anonProfileId),
                communityId: communityId
            )
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: AnonProfileFollowActionResponseDTO = try await apiClient.post(
                "/v1/anon/\(anonProfileId)/follow",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return AnonProfileFollowActionResult(anonProfileId: response.anonProfileId, following: response.following)
        }

        let response: AnonProfileFollowActionResponseDTO = try await apiClient.post(
            "/v1/anon/\(anonProfileId)/follow",
            body: EmptyBody()
        )
        return AnonProfileFollowActionResult(anonProfileId: response.anonProfileId, following: response.following)
    }

    func unfollowAnonProfile(
        anonProfileId: Int,
        asAnonymousActor: Bool,
        communityId: Int?
    ) async throws -> AnonProfileFollowActionResult {
        if asAnonymousActor {
            let anonContext = try await anonService.actionContext(
                for: .unfollowAnonProfile(anonProfileId: anonProfileId),
                communityId: communityId
            )
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: AnonProfileFollowActionResponseDTO = try await apiClient.delete(
                "/v1/anon/\(anonProfileId)/follow",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return AnonProfileFollowActionResult(anonProfileId: response.anonProfileId, following: response.following)
        }

        let response: AnonProfileFollowActionResponseDTO = try await apiClient.delete(
            "/v1/anon/\(anonProfileId)/follow",
            expecting: AnonProfileFollowActionResponseDTO.self
        )
        return AnonProfileFollowActionResult(anonProfileId: response.anonProfileId, following: response.following)
    }

    func fetchUserFollowers(userId: Int, limit: Int, cursor: String?, query: String?) async throws -> UserFollowListPage {
        let resolvedLimit = limit > 0 ? limit : 20
        var endpoint = "/v1/users/\(userId)/followers?limit=\(resolvedLimit)"
        if let cursor, !cursor.isEmpty {
            endpoint += "&cursor=\(URLQueryEncoding.encode(cursor))"
        }
        let trimmedQuery = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            endpoint += "&query=\(URLQueryEncoding.encode(trimmedQuery))"
        }

        let response: UserFollowListResponseDTO = try await apiClient.get(endpoint)
        let items = response.items.map(UserFollowListItem.init(dto:))
        return UserFollowListPage(items: items, nextCursor: response.nextCursor)
    }

    func fetchUserFollowing(userId: Int, limit: Int, cursor: String?, query: String?) async throws -> UserFollowListPage {
        let resolvedLimit = limit > 0 ? limit : 20
        var endpoint = "/v1/users/\(userId)/following?limit=\(resolvedLimit)"
        if let cursor, !cursor.isEmpty {
            endpoint += "&cursor=\(URLQueryEncoding.encode(cursor))"
        }
        let trimmedQuery = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            endpoint += "&query=\(URLQueryEncoding.encode(trimmedQuery))"
        }

        let response: UserFollowListResponseDTO = try await apiClient.get(endpoint)
        let items = response.items.map(UserFollowListItem.init(dto:))
        return UserFollowListPage(items: items, nextCursor: response.nextCursor)
    }
    
    func updateProfile(
        displayName: String?,
        bio: String?,
        isAnonymous: Bool,
        showFollowerCount: Bool?,
        messagePermission: MessagePermission?,
        profileMediaAssetId: Int?
    ) async throws -> User {
        let request = UpdateProfileRequest(
            displayName: displayName,
            bio: bio,
            isAnonymous: isAnonymous,
            showFollowerCount: showFollowerCount,
            messagePermission: messagePermission,
            profileMediaAssetId: profileMediaAssetId
        )
        let dto: UserDTO = try await apiClient.put("/v1/users/me", body: request)
        return User(dto: dto, profile: dto.profile)
    }

    func updateDisplayCommunity(communityId: Int?) async throws -> User {
        let request = DisplayCommunityUpdateRequest(communityId: communityId)
        let data = try await apiClient.putData("/v1/users/me/display-community", body: request)
        if data.isEmpty {
            return try await getCurrentUser()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatterWithFractional.date(from: value) ?? formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let dto = try decoder.decode(UserDTO.self, from: data)
            return User(dto: dto, profile: dto.profile)
        } catch {
            return try await getCurrentUser()
        }
    }

    func updateDisplaySpecialization(specializationId: Int?) async throws -> User {
        let request = DisplaySpecializationUpdateRequest(specializationId: specializationId)
        let data = try await apiClient.putData("/v1/users/me/display-specialization", body: request)
        if data.isEmpty {
            return try await getCurrentUser()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatterWithFractional.date(from: value) ?? formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let dto = try decoder.decode(UserDTO.self, from: data)
            return User(dto: dto, profile: dto.profile)
        } catch {
            return try await getCurrentUser()
        }
    }

    func updateIdentity(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> User {
        let request = UserIdentityUpdateRequestDTO(
            username: username,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth
        )
        let dto: UserDTO = try await apiClient.put("/v1/users/me/identity", body: request)
        return User(dto: dto, profile: dto.profile)
    }
    
    func deleteAccount(mode: DeleteAccountMode = .hard) async throws -> DeleteAccountResult {
        switch mode {
        case .soft:
            let _: EmptyResponse = try await apiClient.post("/v1/users/me/deactivate", body: EmptyBody())
            return DeleteAccountResult(deletePending: false)
        case .hard:
            let response: DeleteAccountResponse = try await apiClient.post("/v1/users/me/delete", body: EmptyBody())
            return DeleteAccountResult(deletePending: response.deletePending ?? false)
        }
    }

    func verifyEmployment(verification: EmploymentVerification) async throws {
        let _: EmptyResponse = try await apiClient.post("/users/verify-employment", body: verification)
    }

    func searchUsers(query: String, limit: Int, cursor: String?) async throws -> UserSearchPage {
        let encodedQuery = URLQueryEncoding.encode(query)
        var endpoint = "/v1/users/search?query=\(encodedQuery)&limit=\(limit)"
        if let cursor, !cursor.isEmpty {
            endpoint += "&cursor=\(URLQueryEncoding.encode(cursor))"
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

    func checkUsernameAvailability(_ username: String) async throws -> UsernameAvailabilityResponseDTO {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        return try await apiClient.get("/v1/users/username/availability?username=\(encoded)")
    }

    func onboardUser(username: String, firstName: String, lastName: String, dateOfBirth: String) async throws -> User {
        let request = UserOnboardRequestDTO(
            username: username,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth
        )
        let dto: UserDTO = try await apiClient.post("/v1/users/onboard", body: request)
        return User(dto: dto, profile: dto.profile)
    }

    func updateOnboardingStep(_ step: RemoteOnboardingStep) async throws -> OnboardingStateDTO {
        let request = UserOnboardingStepUpdateRequestDTO(step: step)
        return try await apiClient.put("/v1/users/me/onboarding", body: request)
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
                isDeleted: dto.isDeleted ?? false,
                createdAt: dto.createdAt,
                updatedAt: dto.createdAt,
                replyToCommentId: dto.parentId != nil ? UUID.fromBackendId(dto.parentId!) : nil,
                replyToBackendId: dto.parentId
            )
        }
        return UserCommentsPage(comments: comments, nextCursor: response.nextCursor)
    }

    func fetchUserReplies(userId: Int, limit: Int, cursor: String?) async throws -> UserRepliesPage {
        var endpoint = "/v1/users/\(userId)/replies?limit=\(limit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: CommentListResponseDTO = try await apiClient.get(endpoint)
        let comments = response.items.map(Comment.init(dto:))
        return UserRepliesPage(comments: comments, nextCursor: response.nextCursor)
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
    let showFollowerCount: Bool?
    let messagePermission: MessagePermission?
    let profileMediaAssetId: Int?
}

private struct DisplayCommunityUpdateRequest: Codable {
    let communityId: Int?
}

private struct DisplaySpecializationUpdateRequest: Codable {
    let specializationId: Int?
}

private struct EmptyBody: Codable {}

private struct DeleteAccountResponse: Codable {
    let status: String?
    let firebaseStatus: String?
    let firebaseDeleted: Bool?
    let deletePending: Bool?
}
