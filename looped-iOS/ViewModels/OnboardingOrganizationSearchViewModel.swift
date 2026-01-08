import Foundation
import Combine

@MainActor
final class OnboardingOrganizationSearchViewModel: ObservableObject {
    enum Scope: Equatable {
        case companiesAndSchools
        case companiesOnly
        case schoolsOnly
    }

    @Published var query = ""
    @Published private(set) var organizations: [Organization] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let scope: Scope
    private let communityService: CommunityServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(
        scope: Scope,
        communityService: CommunityServiceProtocol = CommunityService()
    ) {
        self.scope = scope
        self.communityService = communityService
        bindQuery()
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

        do {
            if trimmed.isEmpty {
                let suggested = try await loadSuggestedOrganizations()
                guard !Task.isCancelled else { return }
                guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
                organizations = suggested
            } else {
                let results = try await searchOrganizations(query: trimmed)
                guard !Task.isCancelled else { return }
                guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
                organizations = results
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard querySnapshot == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            organizations = []
            errorMessage = error.localizedDescription
        }
    }

    private func loadSuggestedOrganizations() async throws -> [Organization] {
        switch scope {
        case .companiesOnly:
            let items = try await communityService.fetchRecommendedCommunities(kind: .company, limit: 40)
            return normalize(items)
        case .schoolsOnly:
            let items = try await communityService.fetchRecommendedCommunities(kind: .school, limit: 40)
            return normalize(items)
        case .companiesAndSchools:
            async let companies = communityService.fetchRecommendedCommunities(kind: .company, limit: 40)
            async let schools = communityService.fetchRecommendedCommunities(kind: .school, limit: 40)
            let (companyItems, schoolItems) = try await (companies, schools)
            return normalize(companyItems + schoolItems)
        }
    }

    private func searchOrganizations(query: String) async throws -> [Organization] {
        switch scope {
        case .companiesOnly:
            let page = try await communityService.searchCommunities(
                query: query,
                limit: 25,
                cursor: nil,
                kind: .company
            )
            return normalize(page.items)
        case .schoolsOnly:
            let page = try await communityService.searchCommunities(
                query: query,
                limit: 25,
                cursor: nil,
                kind: .school
            )
            return normalize(page.items)
        case .companiesAndSchools:
            async let companies = communityService.searchCommunities(
                query: query,
                limit: 25,
                cursor: nil,
                kind: .company
            )
            async let schools = communityService.searchCommunities(
                query: query,
                limit: 25,
                cursor: nil,
                kind: .school
            )
            let (companiesPage, schoolsPage) = try await (companies, schools)
            return normalize(companiesPage.items + schoolsPage.items)
        }
    }

    private func normalize(_ items: [CommunitySearchResult]) -> [Organization] {
        let scope = self.scope
        let allowed: (CommunityKind) -> Bool = { kind in
            switch scope {
            case .companiesOnly:
                return kind == .company
            case .schoolsOnly:
                return kind == .school
            case .companiesAndSchools:
                return kind == .company || kind == .school
            }
        }

        var seen = Set<Int>()
        let filtered = items.filter { item in
            guard allowed(item.kind) else { return false }
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
