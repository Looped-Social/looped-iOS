import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct OnboardingOrganizationSearchViewModelTests {

    @Test
    func refresh_emptyQuery_loadsSuggestedAndNormalizesOrdering() async {
        let service = MockCommunityService()
        service.fetchRecommendedHandler = { kind, _, _ in
            switch kind {
            case .company:
                return SearchResultPage(items: [
                    TestFixtures.communitySearchResult(id: 1, name: "Beta Co", kind: .company, memberCount: 10),
                    TestFixtures.communitySearchResult(id: 2, name: "Alpha Co", kind: .company, memberCount: 30),
                    TestFixtures.communitySearchResult(id: 3, name: "Campus", kind: .school, memberCount: 30)
                ], nextCursor: nil)
            case .school:
                return SearchResultPage(items: [
                    TestFixtures.communitySearchResult(id: 2, name: "Alpha Co", kind: .school, memberCount: 30),
                    TestFixtures.communitySearchResult(id: 3, name: "Campus", kind: .school, memberCount: 30)
                ], nextCursor: nil)
            default:
                return SearchResultPage(items: [], nextCursor: nil)
            }
        }

        let viewModel = OnboardingOrganizationSearchViewModel(
            scope: .companiesAndSchools,
            communityService: service,
            enableQueryBinding: false
        )
        viewModel.query = ""

        await refreshAndWaitForCompletion(viewModel, service: service)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.organizations.compactMap(\.backendId) == [2, 3, 1])
        let requestedKinds = service.fetchRecommendedCalls.compactMap(\.kind)
        #expect(requestedKinds.contains(.company))
        #expect(requestedKinds.allSatisfy { $0 == .company || $0 == .school })
    }

    @Test
    func refresh_withQuery_usesScopedSearch() async {
        let service = MockCommunityService()
        service.searchCommunitiesHandler = { query, _, _, kind in
            #expect(query == "stan")
            #expect(kind == .company)
            return SearchResultPage(items: [
                TestFixtures.communitySearchResult(id: 10, name: "Stanford", kind: .school, memberCount: 50),
                TestFixtures.communitySearchResult(id: 11, name: "Stanley Corp", kind: .company, memberCount: 40)
            ], nextCursor: nil)
        }

        let viewModel = OnboardingOrganizationSearchViewModel(
            scope: .companiesOnly,
            communityService: service,
            enableQueryBinding: false
        )
        viewModel.query = "stan"

        await refreshAndWaitForCompletion(viewModel, service: service)

        #expect(viewModel.organizations.count == 1)
        #expect(viewModel.organizations.first.flatMap(\.backendId) == 11)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func refresh_withQuery_noMatches_setsNoResultsForActiveQuery() async {
        let service = MockCommunityService()
        service.searchCommunitiesHandler = { query, _, _, kind in
            #expect(query == "unknown")
            #expect(kind == .school)
            return SearchResultPage(items: [], nextCursor: nil)
        }

        let viewModel = OnboardingOrganizationSearchViewModel(
            scope: .schoolsOnly,
            communityService: service,
            enableQueryBinding: false
        )
        viewModel.query = "unknown"

        await refreshAndWaitForCompletion(viewModel, service: service)

        #expect(viewModel.organizations.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasNoResultsForActiveQuery == true)
    }

    @Test
    func refresh_emptyQuery_emptySuggestions_keepsNoResultsFlagFalse() async {
        let service = MockCommunityService()
        service.fetchRecommendedHandler = { _, _, _ in
            SearchResultPage(items: [], nextCursor: nil)
        }

        let viewModel = OnboardingOrganizationSearchViewModel(
            scope: .companiesOnly,
            communityService: service,
            enableQueryBinding: false
        )
        viewModel.query = ""

        await refreshAndWaitForCompletion(viewModel, service: service)

        #expect(viewModel.organizations.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasNoResultsForActiveQuery == false)
    }

    @Test
    func refresh_error_setsErrorAndClearsResults() async {
        let service = MockCommunityService()
        service.searchCommunitiesHandler = { _, _, _, _ in
            throw TestError(message: "lookup failed")
        }

        let viewModel = OnboardingOrganizationSearchViewModel(
            scope: .schoolsOnly,
            communityService: service,
            enableQueryBinding: false
        )
        viewModel.query = "mit"

        await refreshAndWaitForCompletion(viewModel, service: service)

        #expect(viewModel.organizations.isEmpty)
        #expect(viewModel.errorMessage == "lookup failed")
    }

    @Test
    func refresh_retryAfterError_recovers() async {
        let service = MockCommunityService()
        var calls = 0
        service.searchCommunitiesHandler = { _, _, _, _ in
            defer { calls += 1 }
            if calls == 0 {
                throw TestError(message: "temporary")
            }
            return SearchResultPage(items: [
                TestFixtures.communitySearchResult(id: 20, name: "Recovered", kind: .school, memberCount: 12)
            ], nextCursor: nil)
        }

        let viewModel = OnboardingOrganizationSearchViewModel(
            scope: .schoolsOnly,
            communityService: service,
            enableQueryBinding: false
        )
        viewModel.query = "rec"

        await refreshAndWaitForCompletion(viewModel, service: service)
        #expect(viewModel.errorMessage == "temporary")

        await refreshAndWaitForCompletion(viewModel, service: service)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.organizations.first.flatMap(\.backendId) == 20)
    }

    @Test
    func refresh_cancelsStaleSearchAndKeepsLatestResults() async {
        let service = MockCommunityService()
        service.searchCommunitiesHandler = { query, _, _, _ in
            if query == "first" {
                try await Task.sleep(nanoseconds: 350_000_000)
                return SearchResultPage(items: [
                    TestFixtures.communitySearchResult(id: 1, name: "Old", kind: .company, memberCount: 1)
                ], nextCursor: nil)
            }
            return SearchResultPage(items: [
                TestFixtures.communitySearchResult(id: 2, name: "New", kind: .company, memberCount: 2)
            ], nextCursor: nil)
        }

        let viewModel = OnboardingOrganizationSearchViewModel(
            scope: .companiesOnly,
            communityService: service,
            enableQueryBinding: false
        )

        viewModel.query = "first"
        viewModel.refresh()

        try? await Task.sleep(nanoseconds: 40_000_000)
        viewModel.query = "second"
        viewModel.refresh()

        await waitFor {
            viewModel.isLoading == false && viewModel.organizations.first.flatMap(\.backendId) == 2
        }

        try? await Task.sleep(nanoseconds: 450_000_000)
        #expect(viewModel.organizations.compactMap(\.backendId) == [2])
    }
}

@MainActor
private func refreshAndWaitForCompletion(
    _ viewModel: OnboardingOrganizationSearchViewModel,
    service: MockCommunityService
) async {
    let initialRecommendedCalls = service.fetchRecommendedCalls.count
    let initialSearchCalls = service.searchCommunitiesCalls.count

    viewModel.refresh()

    await waitFor {
        let requested =
            service.fetchRecommendedCalls.count > initialRecommendedCalls ||
            service.searchCommunitiesCalls.count > initialSearchCalls
        return requested && viewModel.isLoading == false
    }
}

@MainActor
private func waitFor(
    timeout: TimeInterval = 2.0,
    condition: @escaping @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}
