import Foundation

@MainActor
final class CommunityVerificationsViewModel: ObservableObject {
    @Published var items: [CommunityVerification] = []
    @Published var joinLimits: [SpecializationJoinLimit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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
}
