import Foundation

@MainActor
final class CommunityVerificationsViewModel: ObservableObject {
    @Published var items: [CommunityVerification] = []
    @Published var joinLimits: [SpecializationJoinLimit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isUnverifying = false
    @Published var unverifyingCommunityId: Int?

    private let service: CommunityVerificationServiceProtocol
    private let communityService: CommunityServiceProtocol

    init(
        service: CommunityVerificationServiceProtocol = CommunityVerificationService(),
        communityService: CommunityServiceProtocol = CommunityService()
    ) {
        self.service = service
        self.communityService = communityService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let verifications = service.fetchCommunityVerifications()
            async let limits = communityService.fetchSpecializationJoinLimits(type: nil)
            items = try await verifications
            joinLimits = (try? await limits) ?? []
        } catch {
            errorMessage = error.localizedDescription
            items = []
            joinLimits = []
        }
    }

    func unverify(communityId: Int) async -> Bool {
        guard !isUnverifying else { return false }
        isUnverifying = true
        unverifyingCommunityId = communityId
        errorMessage = nil
        defer {
            isUnverifying = false
            unverifyingCommunityId = nil
        }

        do {
            _ = try await service.unverifyCommunity(communityId: communityId)
            await load()
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    private func mapError(_ error: Error) -> String {
        guard case let APIError.apiError(_, apiError, message) = error else {
            return error.localizedDescription
        }

        switch apiError {
        case "user_not_provisioned":
            return "Your account isn’t fully set up yet. Try again in a moment."
        case "community_not_found":
            return "That community no longer exists."
        default:
            if let message, !message.isEmpty {
                return message
            }
            return apiError
        }
    }
}
