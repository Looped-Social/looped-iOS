import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct CommunityVerificationsViewModelTests {

    @Test
    func searchVerificationCommunities_emptyQuery_clearsResultsWithoutNetworkCall() async {
        let verificationService = MockCommunityVerificationService()
        let communityService = MockCommunityService()
        let viewModel = CommunityVerificationsViewModel(
            service: verificationService,
            communityService: communityService
        )

        await viewModel.searchVerificationCommunities(query: "   ")

        #expect(communityService.searchCommunitiesCalls.isEmpty)
        #expect(viewModel.verificationSearchResults.isEmpty)
        #expect(viewModel.verificationSearchError == nil)
        #expect(viewModel.isSearchingVerificationCommunities == false)
    }

    @Test
    func searchVerificationCommunities_singleCharacterQuery_skipsNetworkCall() async {
        let verificationService = MockCommunityVerificationService()
        let communityService = MockCommunityService()
        let viewModel = CommunityVerificationsViewModel(
            service: verificationService,
            communityService: communityService
        )

        await viewModel.searchVerificationCommunities(query: "a")

        #expect(communityService.searchCommunitiesCalls.isEmpty)
        #expect(viewModel.verificationSearchResults.isEmpty)
        #expect(viewModel.verificationSearchError == nil)
        #expect(viewModel.isSearchingVerificationCommunities == false)
    }

    @Test
    func searchVerificationCommunities_usesCompanyKindAndFiltersAlreadyActive() async {
        let verificationService = MockCommunityVerificationService()
        let communityService = MockCommunityService()

        communityService.searchCommunitiesHandler = { query, _, _, kind in
            #expect(query == "looped")
            switch kind {
            case .company:
                return SearchResultPage(
                    items: [
                        TestFixtures.communitySearchResult(id: 1, name: "Looped", kind: .company, memberCount: 100),
                        TestFixtures.communitySearchResult(id: 2, name: "Beta Labs", kind: .company, memberCount: 50)
                    ],
                    nextCursor: nil
                )
            case .school:
                return SearchResultPage(
                    items: [
                        TestFixtures.communitySearchResult(id: 3, name: "Campus", kind: .school, memberCount: 80)
                    ],
                    nextCursor: nil
                )
            default:
                return SearchResultPage(items: [], nextCursor: nil)
            }
        }

        let viewModel = CommunityVerificationsViewModel(
            service: verificationService,
            communityService: communityService
        )
        viewModel.items = [
            makeVerification(communityId: 1, status: .active),
            makeVerification(communityId: 9, status: .expired)
        ]

        await viewModel.searchVerificationCommunities(query: "looped")

        #expect(communityService.searchCommunitiesCalls.count == 2)
        let requestedKinds = Set(communityService.searchCommunitiesCalls.compactMap(\.kind))
        #expect(requestedKinds == Set([.company, .school]))
        #expect(viewModel.verificationSearchResults.compactMap(\.id) == [3, 2])
        #expect(viewModel.verificationSearchError == nil)
    }

    @Test
    func searchVerificationCommunities_whenSearchFails_setsError() async {
        let verificationService = MockCommunityVerificationService()
        let communityService = MockCommunityService()
        communityService.searchCommunitiesHandler = { _, _, _, _ in
            throw TestError(message: "search failed")
        }

        let viewModel = CommunityVerificationsViewModel(
            service: verificationService,
            communityService: communityService
        )

        await viewModel.searchVerificationCommunities(query: "looped")

        #expect(viewModel.verificationSearchResults.isEmpty)
        #expect(viewModel.verificationSearchError == "Couldn't load companies and schools.")
        #expect(viewModel.isSearchingVerificationCommunities == false)
    }

    @Test
    func searchSpecializations_singleCharacterQuery_skipsNetworkCall() async {
        let verificationService = MockCommunityVerificationService()
        let communityService = MockCommunityService()
        let discoveryService = MockDiscoveryService()
        let viewModel = CommunityVerificationsViewModel(
            service: verificationService,
            communityService: communityService,
            discoveryService: discoveryService
        )

        await viewModel.searchSpecializations(query: "m")

        #expect(communityService.searchCommunitiesCalls.isEmpty)
        #expect(discoveryService.fetchMajorsIndexCallCount == 0)
        #expect(discoveryService.fetchFieldsIndexCallCount == 0)
        #expect(viewModel.specializationSearchResults.isEmpty)
        #expect(viewModel.specializationSearchError == nil)
        #expect(viewModel.isSearchingSpecializations == false)
    }

    @Test
    func searchSpecializations_queriesMajorAndFieldAndCombinesResults() async {
        let verificationService = MockCommunityVerificationService()
        let communityService = MockCommunityService()
        let discoveryService = MockDiscoveryService()
        discoveryService.fetchMajorsIndexHandler = {
            [
                SpecializationIndexItem(id: 11, name: "Biology", shortName: nil, icon: nil)
            ]
        }
        discoveryService.fetchFieldsIndexHandler = {
            [
                SpecializationIndexItem(id: 12, name: "Biochemistry", shortName: nil, icon: nil)
            ]
        }

        let viewModel = CommunityVerificationsViewModel(
            service: verificationService,
            communityService: communityService,
            discoveryService: discoveryService
        )

        await viewModel.searchSpecializations(query: "bio")

        #expect(communityService.searchCommunitiesCalls.isEmpty)
        #expect(discoveryService.fetchMajorsIndexCallCount == 1)
        #expect(discoveryService.fetchFieldsIndexCallCount == 1)
        #expect(viewModel.specializationSearchResults.map(\.id) == [11, 12])
        #expect(viewModel.specializationSearchError == nil)
    }

    @Test
    func searchSpecializations_infersTypeFromRequestedEndpointWhenMissing() async {
        let verificationService = MockCommunityVerificationService()
        let communityService = MockCommunityService()
        let discoveryService = MockDiscoveryService()
        discoveryService.fetchMajorsIndexHandler = { [] }
        discoveryService.fetchFieldsIndexHandler = {
            [
                SpecializationIndexItem(id: 77, name: "Biotech", shortName: nil, icon: nil)
            ]
        }

        let viewModel = CommunityVerificationsViewModel(
            service: verificationService,
            communityService: communityService,
            discoveryService: discoveryService
        )

        await viewModel.searchSpecializations(query: "bio")

        #expect(viewModel.specializationSearchResults.count == 1)
        #expect(viewModel.specializationSearchResults.first?.id == 77)
        #expect(viewModel.specializationSearchResults.first?.specializationType == .field)
        #expect(viewModel.specializationSearchError == nil)
    }

    @Test
    func searchSpecializations_usesCachedIndexesAcrossQueries() async {
        let verificationService = MockCommunityVerificationService()
        let communityService = MockCommunityService()
        let discoveryService = MockDiscoveryService()
        discoveryService.fetchMajorsIndexHandler = {
            [SpecializationIndexItem(id: 10, name: "Math", shortName: nil, icon: nil)]
        }
        discoveryService.fetchFieldsIndexHandler = {
            [SpecializationIndexItem(id: 20, name: "Marketing", shortName: nil, icon: nil)]
        }

        let viewModel = CommunityVerificationsViewModel(
            service: verificationService,
            communityService: communityService,
            discoveryService: discoveryService
        )

        await viewModel.searchSpecializations(query: "ma")
        await viewModel.searchSpecializations(query: "mar")

        #expect(discoveryService.fetchMajorsIndexCallCount == 1)
        #expect(discoveryService.fetchFieldsIndexCallCount == 1)
    }
}

private func makeVerification(
    communityId: Int,
    status: CommunityVerificationStatus
) -> CommunityVerification {
    CommunityVerification(
        communityId: communityId,
        communityName: "Community \(communityId)",
        communityKind: .company,
        method: .email,
        verified: status == .active || status == .expired,
        verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
        expiresAt: status == .expired ? Date(timeIntervalSince1970: 1_600_000_000) : nil,
        active: status == .active,
        status: status,
        rejectReason: nil,
        verifiedEmail: "user\(communityId)@example.com"
    )
}
