import Foundation

@MainActor
class ViolationsViewModel: ObservableObject {
    @Published var violations: [Violation] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let moderationService: ModerationServiceProtocol
    private var nextCursor: String?

    init(moderationService: ModerationServiceProtocol = ModerationService()) {
        self.moderationService = moderationService
    }

    func loadViolations() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await moderationService.fetchViolations(limit: 20, cursor: nil)
            violations = page.violations
            nextCursor = page.nextCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current: Violation) async {
        guard let nextCursor, !isLoadingMore else { return }
        guard current.id == violations.last?.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await moderationService.fetchViolations(limit: 20, cursor: nextCursor)
            violations.append(contentsOf: page.violations)
            self.nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
