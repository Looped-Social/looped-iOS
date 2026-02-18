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

    func fetchMyShareLink() async throws -> UserShareLink {
        let response: UserShareLinkDTO = try await apiClient.get("/v1/users/me/share-link")
        return UserShareLink(dto: response)
    }

    func checkSlugAvailability(_ slug: String) async throws -> UserSlugAvailability {
        let encodedSlug = URLQueryEncoding.encode(slug)
        let response: UserSlugAvailabilityDTO = try await apiClient.get("/v1/users/slug/availability?slug=\(encodedSlug)")
        return UserSlugAvailability(dto: response)
    }

    func resolveUserId(fromSlug slug: String) async throws -> Int {
        let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let endpoints = [
            "/v1/users/slug/\(encodedSlug)",
            "/v1/users/by-slug/\(encodedSlug)",
            "/v1/users/share-link/\(encodedSlug)"
        ]

        for endpoint in endpoints {
            do {
                let data = try await apiClient.getData(endpoint)
                if let userId = Self.userIdFromSlugResponse(data) {
                    return userId
                }
            } catch {
                guard isNotFound(error) else { throw error }
            }
        }

        let page = try await searchUsers(query: slug, limit: 25, cursor: nil)
        let normalizedSlug = slug.lowercased()
        if let match = page.users.first(where: { user in
            user.username?.lowercased() == normalizedSlug || user.handle.lowercased() == normalizedSlug
        }) {
            return match.backendId
        }

        throw UserServiceError.userSlugNotFound(slug)
    }

    func updateMyShareLink(customSlug: String?) async throws -> UserShareLink {
        let request = UpdateShareLinkRequestDTO(customSlug: customSlug)
        let response: UserShareLinkDTO = try await apiClient.put("/v1/users/me/share-link", body: request)
        return UserShareLink(dto: response)
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

    func markOnboardingInfoScreenViewed() async throws -> OnboardingStateV2DTO {
        try await apiClient.post(
            "/v1/users/me/onboarding-v2/info-screen/viewed",
            body: EmptyBody()
        )
    }

    func setOnboardingV2Organization(orgId: Int) async throws -> OnboardingStateV2DTO {
        let request = OnboardingV2OrgRequestDTO(orgId: orgId)
        return try await apiClient.put("/v1/users/me/onboarding-v2/org", body: request)
    }

    func setOnboardingV2VerificationChoice(path: String) async throws -> OnboardingStateV2DTO {
        let request = OnboardingV2VerificationChoiceRequestDTO(verificationPath: path)
        return try await apiClient.put("/v1/users/me/onboarding-v2/verification-choice", body: request)
    }

    func markOnboardingV2EmailVerificationSuccess() async throws -> OnboardingStateV2DTO {
        try await apiClient.post(
            "/v1/users/me/onboarding-v2/email-verification/success",
            body: EmptyBody()
        )
    }

    func submitOnboardingV2Specialization(specializationId: Int) async throws -> OnboardingStateV2DTO {
        let request = OnboardingV2SpecializationRequestDTO(specializationId: specializationId)
        return try await apiClient.post("/v1/users/me/onboarding-v2/specialization", body: request)
    }

    func acknowledgeOnboardingV2SkipExplainer() async throws -> OnboardingStateV2DTO {
        try await apiClient.post(
            "/v1/users/me/onboarding-v2/skip-explainer/ack",
            body: EmptyBody()
        )
    }

    func acknowledgeOnboardingV2PhotoPendingExplainer() async throws -> OnboardingStateV2DTO {
        try await apiClient.post(
            "/v1/users/me/onboarding-v2/photo-pending-explainer/ack",
            body: EmptyBody()
        )
    }

    func finalizeOnboardingV2() async throws -> OnboardingStateV2DTO {
        try await apiClient.post(
            "/v1/users/me/onboarding-v2/finalize",
            body: EmptyBody()
        )
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

    private func isNotFound(_ error: Error) -> Bool {
        switch error {
        case APIError.serverError(let code):
            return code == 404
        case APIError.apiError(let code, _, _):
            return code == 404
        default:
            return false
        }
    }

    private static func userIdFromSlugResponse(_ data: Data) -> Int? {
        if let dto = try? JSONDecoder().decode(UserDTO.self, from: data) {
            return dto.id
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return userId(from: object)
    }

    private static func userId(from object: Any) -> Int? {
        if let number = object as? NSNumber {
            return number.intValue
        }

        if let dictionary = object as? [String: Any] {
            if let nestedUser = dictionary["user"], let id = userId(from: nestedUser) {
                return id
            }
            if let nestedData = dictionary["data"], let id = userId(from: nestedData) {
                return id
            }
            if let nestedResult = dictionary["result"], let id = userId(from: nestedResult) {
                return id
            }
            if let nestedProfile = dictionary["profile"], let id = userId(from: nestedProfile) {
                return id
            }

            if let value = dictionary["userId"] as? NSNumber {
                return value.intValue
            }
            if let value = dictionary["user_id"] as? NSNumber {
                return value.intValue
            }

            if let idValue = dictionary["id"] as? NSNumber {
                let hasUserShape = dictionary["handle"] != nil
                    || dictionary["username"] != nil
                    || dictionary["displayName"] != nil
                    || dictionary["display_name"] != nil
                if hasUserShape {
                    return idValue.intValue
                }
            }

        }

        if let array = object as? [Any] {
            for value in array {
                if let id = userId(from: value) {
                    return id
                }
            }
        }

        return nil
    }
}

enum UserServiceError: Error, LocalizedError {
    case userNotProvisioned
    case userSlugNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotProvisioned:
            return "Your account isn't fully onboarded yet."
        case .userSlugNotFound(let slug):
            return "Could not find a profile for slug '\(slug)'."
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

private extension UserShareLink {
    init(dto: UserShareLinkDTO) {
        usernameSlug = dto.usernameSlug
        customSlug = dto.customSlug
        activeSlug = dto.activeSlug
        canonicalUrl = dto.canonicalUrl
    }
}

private extension UserSlugAvailability {
    init(dto: UserSlugAvailabilityDTO) {
        slug = dto.slug
        available = dto.available
        ownedByMe = dto.ownedByMe ?? false
        reserved = dto.reserved ?? false
    }
}
