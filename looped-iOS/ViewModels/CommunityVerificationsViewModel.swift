import Foundation

@MainActor
final class CommunityVerificationsViewModel: ObservableObject {
    @Published var items: [CommunityVerification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: CommunityVerificationServiceProtocol

    init(service: CommunityVerificationServiceProtocol = CommunityVerificationService()) {
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await service.fetchCommunityVerifications()
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }
}
