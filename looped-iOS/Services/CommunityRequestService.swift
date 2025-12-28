import Foundation

class CommunityRequestService: CommunityRequestServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func createCommunityRequest(
        kind: CommunityRequestKind,
        name: String,
        about: String,
        imageKey: String?
    ) async throws -> CommunityRequestSubmission {
        let request = CommunityRequestCreateRequestDTO(
            type: kind.rawValue,
            name: name,
            about: about,
            imageKey: imageKey
        )
        let response: CommunityRequestCreateResponseDTO = try await apiClient.post(
            "/v1/community-requests",
            body: request
        )
        let status = CommunityRequestStatus(rawValue: response.status) ?? .unknown
        return CommunityRequestSubmission(id: response.id, status: status)
    }

    func fetchCommunityRequests(status: CommunityRequestStatus?) async throws -> [CommunityRequest] {
        var endpoint = "/v1/community-requests"
        if let status {
            endpoint += "?status=\(status.rawValue)"
        }
        let response: CommunityRequestListDTO = try await apiClient.get(endpoint)
        return response.items.map(CommunityRequest.init(dto:))
    }
}
