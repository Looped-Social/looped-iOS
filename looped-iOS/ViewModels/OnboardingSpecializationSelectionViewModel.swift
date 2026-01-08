import Foundation
import Combine

@MainActor
final class OnboardingSpecializationSelectionViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [CommunitySearchResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let kind: CommunitySearchKind
    private let communityService: CommunityServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(
        kind: CommunitySearchKind,
        communityService: CommunityServiceProtocol = CommunityService()
    ) {
        self.kind = kind
        self.communityService = communityService
        bindQuery()
    }

    func refresh() {
        searchTask?.cancel()
        searchTask = Task { await performLoad(query: query) }
    }

    private func bindQuery() {
        $query
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task { await self.performLoad(query: value) }
            }
            .store(in: &cancellables)
    }

    private func performLoad(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let querySnapshot = trimmed

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let items: [CommunitySearchResult]
            if trimmed.isEmpty {
                items = try await communityService.fetchRecommendedCommunities(kind: kind, limit: 50)
            } else {
                let page = try await communityService.searchCommunities(
                    query: trimmed,
                    limit: 50,
                    cursor: nil,
                    kind: kind
                )
                items = page.items
            }

            guard !Task.isCancelled else { return }
            guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

            results = items
                .sorted {
                    if $0.memberCount != $1.memberCount { return $0.memberCount > $1.memberCount }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
        } catch {
            guard !Task.isCancelled else { return }
            guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            results = []
            errorMessage = error.localizedDescription
        }
    }
}
