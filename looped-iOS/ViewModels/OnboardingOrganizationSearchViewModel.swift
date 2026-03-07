import Foundation
import Combine

@MainActor
final class OnboardingOrganizationSearchViewModel: ObservableObject {
    enum Scope: Equatable {
        case companiesAndSchools
        case companiesOnly
        case schoolsOnly

        var preferredRequestKind: CommunityRequestKind? {
            switch self {
            case .companiesOnly:
                return .company
            case .companiesAndSchools, .schoolsOnly:
                return .company
            }
        }
    }

    @Published var query = ""
    @Published private(set) var organizations: [Organization] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasNoResultsForActiveQuery = false

    private let communityService: CommunityServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(
        scope: Scope,
        communityService: CommunityServiceProtocol = CommunityService(),
        enableQueryBinding: Bool = true
    ) {
        _ = scope
        self.communityService = communityService
        if enableQueryBinding {
            bindQuery()
        }
    }

    func refresh() {
        searchTask?.cancel()
        searchTask = Task { await performSearch(query: query) }
    }

    private func bindQuery() {
        $query
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task { await self.performSearch(query: value) }
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let querySnapshot = trimmed

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        hasNoResultsForActiveQuery = false

        do {
            if trimmed.isEmpty {
                let suggested = try await loadSuggestedOrganizations(fallbackQuery: querySnapshot)
                guard !Task.isCancelled else { return }
                guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
                organizations = suggested
                hasNoResultsForActiveQuery = false
            } else {
                let results = try await searchOrganizations(query: trimmed)
                guard !Task.isCancelled else { return }
                guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
                organizations = results
                hasNoResultsForActiveQuery = results.isEmpty
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            organizations = []
            errorMessage = error.localizedDescription
            hasNoResultsForActiveQuery = false
        }
    }

    private func loadSuggestedOrganizations(fallbackQuery: String) async throws -> [Organization] {
        do {
            let items = try await communityService.fetchRecommendedCommunities(kind: .company, limit: 40)
            return normalize(items)
        } catch {
            let normalizedFallbackQuery = fallbackQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedFallbackQuery.isEmpty else {
                throw error
            }
            let fallback = try? await searchOrganizations(query: normalizedFallbackQuery)
            if let fallback {
                return fallback
            }
            throw error
        }
    }

    private func searchOrganizations(query: String) async throws -> [Organization] {
        let page = try await communityService.searchCommunities(
            query: query,
            limit: 25,
            cursor: nil,
            kind: .company
        )
        return normalize(page.items)
    }

    private func normalize(_ items: [CommunitySearchResult]) -> [Organization] {
        var seen = Set<Int>()
        let filtered = items.filter { item in
            guard item.kind == .company else { return false }
            return seen.insert(item.id).inserted
        }

        return filtered
            .sorted {
                if $0.memberCount != $1.memberCount { return $0.memberCount > $1.memberCount }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .map(Organization.init(community:))
    }
}
