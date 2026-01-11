import Foundation

final class BlockService: BlockServiceProtocol {
    private let apiClient: APIClient
    private let anonService: AnonService

    init(apiClient: APIClient = APIClient(), anonService: AnonService = .shared) {
        self.apiClient = apiClient
        self.anonService = anonService
    }

    func fetchBlockedUsers(limit: Int, cursor: String?) async throws -> BlockedUsersPage {
        var endpoint = "/v1/users/blocked?limit=\(limit)"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: BlockedUsersResponseDTO = try await apiClient.get(endpoint)
        let users = response.items.map { BlockedUser(dto: $0) }
        return BlockedUsersPage(users: users, nextCursor: response.nextCursor)
    }

    func blockUser(userId: Int) async throws -> BlockActionResult {
        try await blockUser(userId: userId, asAnonymousActor: anonService.isAnonymousEnabled, communityId: nil)
    }

    func unblockUser(userId: Int) async throws -> BlockActionResult {
        try await unblockUser(userId: userId, asAnonymousActor: anonService.isAnonymousEnabled, communityId: nil)
    }

    func blockUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> BlockActionResult {
        if asAnonymousActor {
            let anonContext = try await anonService.actionContext(for: .blockUser(userId: userId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: BlockActionResponseDTO = try await apiClient.post(
                "/v1/users/\(userId)/block",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return BlockActionResult(userId: response.userId, blocked: response.blocked)
        }

        let response: BlockActionResponseDTO = try await apiClient.post(
            "/v1/users/\(userId)/block",
            body: EmptyBody()
        )
        return BlockActionResult(userId: response.userId, blocked: response.blocked)
    }

    func unblockUser(userId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> BlockActionResult {
        if asAnonymousActor {
            let anonContext = try await anonService.actionContext(for: .unblockUser(userId: userId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: BlockActionResponseDTO = try await apiClient.delete(
                "/v1/users/\(userId)/block",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return BlockActionResult(userId: response.userId, blocked: response.blocked)
        }

        let response: BlockActionResponseDTO = try await apiClient.delete(
            "/v1/users/\(userId)/block",
            expecting: BlockActionResponseDTO.self
        )
        return BlockActionResult(userId: response.userId, blocked: response.blocked)
    }

    func blockPrincipal(principalId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> PrincipalBlockActionResult {
        if asAnonymousActor {
            let anonContext = try await anonService.actionContext(for: .blockPrincipal(principalId: principalId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PrincipalBlockActionResponseDTO = try await apiClient.post(
                "/v1/principals/\(principalId)/block",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return PrincipalBlockActionResult(principalId: response.principalId, blocked: response.blocked)
        }

        let response: PrincipalBlockActionResponseDTO = try await apiClient.post(
            "/v1/principals/\(principalId)/block",
            body: EmptyBody()
        )
        return PrincipalBlockActionResult(principalId: response.principalId, blocked: response.blocked)
    }

    func unblockPrincipal(principalId: Int, asAnonymousActor: Bool, communityId: Int?) async throws -> PrincipalBlockActionResult {
        if asAnonymousActor {
            let anonContext = try await anonService.actionContext(for: .unblockPrincipal(principalId: principalId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PrincipalBlockActionResponseDTO = try await apiClient.delete(
                "/v1/principals/\(principalId)/block",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return PrincipalBlockActionResult(principalId: response.principalId, blocked: response.blocked)
        }

        let response: PrincipalBlockActionResponseDTO = try await apiClient.delete(
            "/v1/principals/\(principalId)/block",
            expecting: PrincipalBlockActionResponseDTO.self
        )
        return PrincipalBlockActionResult(principalId: response.principalId, blocked: response.blocked)
    }
}

private struct EmptyBody: Codable {}
