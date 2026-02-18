import Foundation

final class PollsService: PollsServiceProtocol {
    private let apiClient: APIClient
    private let anonService: AnonService
    private let anonHeaders = ["X-Actor": "anon"]
    private let isAnonymousModeEnabled: () -> Bool
    private let recoverAnonIdentity: (_ communityId: Int?) async throws -> Void

    init(
        apiClient: APIClient = APIClient(),
        anonService: AnonService = .shared,
        isAnonymousModeEnabled: (() -> Bool)? = nil,
        recoverAnonIdentity: ((_ communityId: Int?) async throws -> Void)? = nil
    ) {
        self.apiClient = apiClient
        self.anonService = anonService
        self.isAnonymousModeEnabled = isAnonymousModeEnabled ?? { [anonService] in
            anonService.isAnonymousEnabled
        }
        self.recoverAnonIdentity = recoverAnonIdentity ?? { [anonService] communityId in
            await anonService.clearIdentity()
            _ = try await anonService.ensureIdentity(communityId: communityId)
        }
    }

    func vote(pollId: Int, selectedOptionIds: [Int], communityId: Int?) async throws -> Poll {
        if isAnonymousModeEnabled() {
            return try await voteAsAnonymous(
                pollId: pollId,
                selectedOptionIds: selectedOptionIds,
                communityId: communityId,
                canRecoverIdentity: true
            )
        }

        let body = PollVoteRequestDTO(selectedOptionIds: selectedOptionIds)
        let dto: PollDTO = try await apiClient.put("/v1/polls/\(pollId)/vote", body: body)
        return Poll(dto: dto)
    }

    private func voteAsAnonymous(
        pollId: Int,
        selectedOptionIds: [Int],
        communityId: Int?,
        canRecoverIdentity: Bool
    ) async throws -> Poll {
        do {
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
        } catch {
            guard canRecoverIdentity, shouldRecoverFromInvalidAnonProof(error) else {
                throw error
            }
            try await recoverAnonIdentity(communityId)
            return try await voteAsAnonymous(
                pollId: pollId,
                selectedOptionIds: selectedOptionIds,
                communityId: communityId,
                canRecoverIdentity: false
            )
        }
    }

    private func shouldRecoverFromInvalidAnonProof(_ error: Error) -> Bool {
        guard case let APIError.apiError(_, apiError, _) = error else { return false }
        return apiError == "invalid_anon_proof"
    }
}
