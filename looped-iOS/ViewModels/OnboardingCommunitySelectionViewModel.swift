import Foundation
import Combine

@MainActor
final class OnboardingCommunitySelectionViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var communities: [SearchResultLoop] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let recommendedKind: CommunitySearchKind?
    private let communityService: CommunityServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(
        recommendedKind: CommunitySearchKind? = nil,
        communityService: CommunityServiceProtocol = CommunityService()
    ) {
        self.recommendedKind = recommendedKind
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
                items = try await communityService.fetchRecommendedCommunities(kind: recommendedKind, limit: 50)
            } else {
                let page = try await communityService.searchCommunities(
                    query: trimmed,
                    limit: 50,
                    cursor: nil,
                    kind: recommendedKind
                )
                items = page.items
            }

            guard !Task.isCancelled else { return }
            guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

            let filtered = items.filter { $0.kind != .company && $0.kind != .school }
            let selectedItems = filtered.isEmpty ? items : filtered

            communities = selectedItems
                .sorted {
                    if $0.memberCount != $1.memberCount { return $0.memberCount > $1.memberCount }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                .map { result in
                    SearchResultLoop(
                        id: UUID.fromBackendId(result.id),
                        backendId: result.id,
                        name: result.name,
                        shortName: result.shortName,
                        description: result.description,
                        kind: result.kind,
                        specializationType: result.specializationType,
                        memberCount: result.memberCount,
                        bannerImageUrl: result.bannerImageUrl,
                        profileImageUrl: result.profileImageUrl,
                        imageUrl: result.imageUrl
                    )
                }
        } catch {
            guard !Task.isCancelled else { return }
            guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            communities = []
            errorMessage = error.localizedDescription
        }
    }
}
