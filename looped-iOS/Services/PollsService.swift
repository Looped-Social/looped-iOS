import Foundation

final class PollsService: PollsServiceProtocol {
    private let apiClient: APIClient
    private let anonService: AnonService
    private let anonHeaders = ["X-Actor": "anon"]

    init(apiClient: APIClient = APIClient(), anonService: AnonService = .shared) {
        self.apiClient = apiClient
        self.anonService = anonService
    }

    func vote(pollId: Int, selectedOptionIds: [Int], communityId: Int?) async throws -> Poll {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(
                for: .pollVote(pollId: pollId),
                communityId: communityId
            )
            let body = PollVoteRequestDTO(
                selectedOptionIds: selectedOptionIds,
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let dto: PollDTO = try await apiClient.put(
                "/v1/polls/\(pollId)/vote",
                body: body,
                requiresAuth: false,
                headers: anonHeaders
            )
            return Poll(dto: dto)
        }

        let body = PollVoteRequestDTO(selectedOptionIds: selectedOptionIds)
        let dto: PollDTO = try await apiClient.put("/v1/polls/\(pollId)/vote", body: body)
        return Poll(dto: dto)
    }
}
