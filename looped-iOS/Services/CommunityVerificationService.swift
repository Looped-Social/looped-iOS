import Foundation

class CommunityVerificationService: CommunityVerificationServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchCommunityVerifications() async throws -> [CommunityVerification] {
        let response: CommunityVerificationListDTO = try await apiClient.get("/v1/communities/verifications")
        return response.items.map(CommunityVerification.init(dto:))
    }

    func startVerification(
        communityId: Int,
        method: CommunityVerificationMethod,
        email: String?
    ) async throws -> CommunityVerificationStartResponse {
        let request = CommunityVerificationStartRequestDTO(method: method.rawValue, email: email)
        let response: CommunityVerificationStartResponseDTO = try await apiClient.post(
            "/v1/communities/\(communityId)/verification/start",
            body: request
        )
        return CommunityVerificationStartResponse(dto: response)
    }

    func finishVerification(
        communityId: Int,
        request: CommunityVerificationFinishRequest
    ) async throws -> CommunityVerificationFinishResponse {
        let body = CommunityVerificationFinishRequestDTO(
            method: request.method.rawValue,
            code: request.code,
            mediaKey: request.mediaKey,
            token: request.token,
            email: request.email
        )
        let response: CommunityVerificationFinishResponseDTO = try await apiClient.post(
            "/v1/communities/\(communityId)/verification/finish",
            body: body
        )
        return CommunityVerificationFinishResponse(dto: response)
    }

    func unverifyCommunity(communityId: Int) async throws -> CommunityVerificationUnverifyResponse {
        let response: CommunityVerificationUnverifyResponseDTO = try await apiClient.delete(
            "/v1/communities/\(communityId)/verification",
            expecting: CommunityVerificationUnverifyResponseDTO.self
        )
        return CommunityVerificationUnverifyResponse(dto: response)
    }
}
