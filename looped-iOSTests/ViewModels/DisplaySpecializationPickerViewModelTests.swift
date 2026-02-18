import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct DisplaySpecializationPickerViewModelTests {

    @Test
    func reload_emptyQuery_usesBrowseForSelectedFilter() async {
        let communityService = MockCommunityService()
        let discoveryService = MockDiscoveryService()
        discoveryService.browseSpecializationsHandler = { type, _, _ in
            #expect(type == .major)
            return SearchResultPage(
                items: [
                    makeSpecialization(id: 1, name: "Computer Science", type: .major, isJoined: true),
                    CommunitySearchResult(
                        id: 90,
                        name: "Looped HQ",
                        description: "",
                        kind: .company,
                        specializationType: .unknown,
                        memberCount: 10,
                        imageUrl: nil,
                        icon: nil,
                        isFollowing: nil,
                        isJoined: nil
                    )
                ],
                nextCursor: nil
            )
        }

        let viewModel = DisplaySpecializationPickerViewModel(
            communityService: communityService,
            discoveryService: discoveryService,
            pageLimit: 20
        )

        await viewModel.reload(query: "   ", filter: .major)

        #expect(communityService.searchCommunitiesCalls.isEmpty)
        #expect(discoveryService.browseSpecializationsCalls.count == 1)
        #expect(discoveryService.browseSpecializationsCalls[0].type == .major)
        #expect(viewModel.results.compactMap(\.id) == [1])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func reload_nonEmptyQuery_usesSearchWithFilterKind() async {
        let communityService = MockCommunityService()
        let discoveryService = MockDiscoveryService()
        communityService.searchCommunitiesHandler = { query, _, _, kind in
            #expect(query == "data")
            #expect(kind == .field)
            return SearchResultPage(
                items: [
                    makeSpecialization(id: 7, name: "Data Science", type: .field, isJoined: false)
                ],
                nextCursor: nil
            )
        }

        let viewModel = DisplaySpecializationPickerViewModel(
            communityService: communityService,
            discoveryService: discoveryService,
            pageLimit: 20
        )

        await viewModel.reload(query: " data ", filter: .field)

        #expect(communityService.searchCommunitiesCalls.count == 1)
        #expect(communityService.searchCommunitiesCalls[0].kind == .field)
        #expect(discoveryService.browseSpecializationsCalls.isEmpty)
        #expect(viewModel.results.compactMap(\.id) == [7])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadMoreIfNeeded_appendsUniqueResultsFromNextPage() async {
        let communityService = MockCommunityService()
        let discoveryService = MockDiscoveryService()

        discoveryService.browseSpecializationsHandler = { type, _, cursor in
            #expect(type == .major)
            if cursor == nil {
                return SearchResultPage(
                    items: [
                        makeSpecialization(id: 1, name: "Computer Science", type: .major, isJoined: true),
                        makeSpecialization(id: 2, name: "Mathematics", type: .major, isJoined: false)
                    ],
                    nextCursor: "next-1"
                )
            }
            #expect(cursor == "next-1")
            return SearchResultPage(
                items: [
                    makeSpecialization(id: 2, name: "Mathematics", type: .major, isJoined: false),
                    makeSpecialization(id: 3, name: "Physics", type: .major, isJoined: true)
                ],
                nextCursor: nil
            )
        }

        let viewModel = DisplaySpecializationPickerViewModel(
            communityService: communityService,
            discoveryService: discoveryService,
            pageLimit: 20
        )

        await viewModel.reload(query: "", filter: .major)
        await viewModel.loadMoreIfNeeded(currentId: 2, query: "", filter: .major)

        #expect(discoveryService.browseSpecializationsCalls.count == 2)
        #expect(viewModel.results.compactMap(\.id) == [1, 2, 3])
        #expect(viewModel.hasMorePages == false)
    }
}

private func makeSpecialization(
    id: Int,
    name: String,
    type: CommunitySpecializationType,
    isJoined: Bool
) -> CommunitySearchResult {
    CommunitySearchResult(
        id: id,
        name: name,
        description: "",
        kind: .specialization,
        specializationType: type,
        memberCount: 100,
        imageUrl: nil,
        icon: nil,
        isFollowing: nil,
        isJoined: isJoined
    )
}
