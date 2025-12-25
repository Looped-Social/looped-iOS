import Foundation

@MainActor
class AppealsViewModel: ObservableObject {
    @Published var appeals: [Appeal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let moderationService: ModerationServiceProtocol

    init(moderationService: ModerationServiceProtocol = ModerationService()) {
        self.moderationService = moderationService
    }

    func loadAppeals(status: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            appeals = try await moderationService.fetchAppeals(status: status)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
