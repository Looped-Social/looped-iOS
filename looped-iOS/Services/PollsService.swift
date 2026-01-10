import Foundation

final class PollsService: PollsServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func vote(pollId: Int, selectedOptionIds: [Int]) async throws -> Poll {
        let body = PollVoteRequestDTO(selectedOptionIds: selectedOptionIds)
        let dto: PollDTO = try await apiClient.put(
            "/v1/polls/\(pollId)/vote",
            body: body,
            requiresAuth: true
        )
        return Poll(dto: dto)
    }
}

