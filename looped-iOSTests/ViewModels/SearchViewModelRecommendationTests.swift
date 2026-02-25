import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct SearchViewModelRecommendationTests {
    @Test
    func loadPeopleRecommendations_retriesWithFollowedCommunityWhenDisplayCommunityMissing() async {
        let communityService = MockCommunityService()
        communityService.fetchFollowedCommunitiesHandler = { _, _, _ in
            CommunityPage(
                items: [
                    CommunitySummary(
                        id: 222,
                        name: "UNC",
                        shortName: nil,
                        kind: .school,
                        memberCount: 10,
                        isPinned: false,
                        sortOrder: nil,
                        canPost: true
                    )
                ],
                nextCursor: nil
            )
        }
        communityService.fetchRecommendedHandler = { _, _, _ in
            SearchResultPage(items: [], nextCursor: nil)
        }

        let feedService = MockFeedService()
        feedService.fetchTrendingPostsHandler = { _, _ in [] }

        let discoveryService = MockDiscoveryService()
        discoveryService.browseSpecializationsHandler = { _, _, _ in
            SearchResultPage(items: [], nextCursor: nil)
        }
        discoveryService.fetchMajorsIndexHandler = { [] }
        discoveryService.fetchFieldsIndexHandler = { [] }

        let userService = MockUserService()
        userService.getCurrentUserHandler = {
            TestFixtures.user(backendId: 101, handle: "user101")
        }

        let recommendationService = MockPeopleRecommendationService()
        recommendationService.fetchRailsHandler = { _, communityId, _, _ in
            if communityId == 222 {
                return PeopleRecommendationRailsBundle(
                    requestId: "req-2",
                    surface: .search,
                    community: PeopleRecommendationCommunity(id: 222, name: "UNC"),
                    rails: [makeRecommendationRail(items: [makeRecommendationItem(userId: 9001)])],
                    experiment: nil,
                    degraded: false,
                    generatedAt: Date()
                )
            }

            return PeopleRecommendationRailsBundle(
                requestId: "req-1",
                surface: .search,
                community: nil,
                rails: [makeRecommendationRail(items: [])],
                experiment: nil,
                degraded: false,
                generatedAt: Date()
            )
        }

        let viewModel = SearchViewModel(
            communityService: communityService,
            feedService: feedService,
            discoveryService: discoveryService,
            peopleRecommendationService: recommendationService,
            userService: userService
        )

        await viewModel.loadPeopleRecommendations()

        #expect(recommendationService.fetchRailsCalls.contains(where: { $0.surface == .search && $0.communityId == nil }))
        #expect(recommendationService.fetchRailsCalls.contains(where: { $0.surface == .search && $0.communityId == 222 }))
        #expect(communityService.fetchFollowedCommunitiesCalls.isEmpty == false)
        #expect(viewModel.peopleRecommendationRails.contains(where: { !$0.items.isEmpty }))
    }

    @Test
    func loadMorePeopleRecommendations_usesResolvedCommunityIdFromInitialLoad() async {
        let communityService = MockCommunityService()
        communityService.fetchRecommendedHandler = { _, _, _ in
            SearchResultPage(items: [], nextCursor: nil)
        }

        let feedService = MockFeedService()
        feedService.fetchTrendingPostsHandler = { _, _ in [] }

        let discoveryService = MockDiscoveryService()
        discoveryService.browseSpecializationsHandler = { _, _, _ in
            SearchResultPage(items: [], nextCursor: nil)
        }
        discoveryService.fetchMajorsIndexHandler = { [] }
        discoveryService.fetchFieldsIndexHandler = { [] }

        let userService = MockUserService()
        userService.getCurrentUserHandler = {
            makeUser(backendId: 102, displayCommunityId: 77)
        }

        let recommendationService = MockPeopleRecommendationService()
        recommendationService.fetchRailsHandler = { _, communityId, _, _ in
            #expect(communityId == 77)
            return PeopleRecommendationRailsBundle(
                requestId: "req-3",
                surface: .search,
                community: PeopleRecommendationCommunity(id: 77, name: "Community 77"),
                rails: [
                    PeopleRecommendationRailPage(
                        requestId: "req-3",
                        rail: .pymk,
                        title: "People You May Know",
                        items: [makeRecommendationItem(userId: 9002)],
                        nextCursor: "cursor-1",
                        hasMore: true,
                        degraded: false,
                        community: nil,
                        experiment: nil
                    )
                ],
                experiment: nil,
                degraded: false,
                generatedAt: Date()
            )
        }
        recommendationService.fetchRailHandler = { rail, surface, communityId, _, cursor in
            #expect(rail == .pymk)
            #expect(surface == .search)
            #expect(communityId == 77)
            #expect(cursor == "cursor-1")
            return PeopleRecommendationRailPage(
                requestId: "req-4",
                rail: .pymk,
                title: "People You May Know",
                items: [makeRecommendationItem(userId: 9003)],
                nextCursor: nil,
                hasMore: false,
                degraded: false,
                community: nil,
                experiment: nil
            )
        }

        let viewModel = SearchViewModel(
            communityService: communityService,
            feedService: feedService,
            discoveryService: discoveryService,
            peopleRecommendationService: recommendationService,
            userService: userService
        )

        await viewModel.loadPeopleRecommendations()
        await viewModel.loadMorePeopleRecommendations(for: .pymk)

        #expect(recommendationService.fetchRailCalls.contains(where: { $0.communityId == 77 }))
        #expect(viewModel.peopleRecommendationRails.first(where: { $0.rail == .pymk })?.items.count == 2)
    }
}

private func makeRecommendationRail(items: [PeopleRecommendationItem]) -> PeopleRecommendationRailPage {
    PeopleRecommendationRailPage(
        requestId: "req",
        rail: .community,
        title: "People in Community",
        items: items,
        nextCursor: nil,
        hasMore: false,
        degraded: false,
        community: nil,
        experiment: nil
    )
}

private func makeRecommendationItem(userId: Int) -> PeopleRecommendationItem {
    PeopleRecommendationItem(
        recommendationId: "rec-\(userId)",
        user: PeopleRecommendationUser(
            id: userId,
            handle: "user\(userId)",
            displayName: "User \(userId)",
            avatarURL: nil,
            headline: nil,
            community: nil
        ),
        reasons: [PeopleRecommendationReason(code: "community", text: "In your community")],
        actions: PeopleRecommendationActions(canConnect: true, canHide: true, canLessLikeThis: true),
        tracking: PeopleRecommendationTracking(token: "trk-\(userId)", position: 1)
    )
}

private func makeUser(backendId: Int, displayCommunityId: Int) -> User {
    User(
        id: UUID.fromBackendId(backendId),
        backendId: backendId,
        username: "user\(backendId)",
        displayName: "User \(backendId)",
        firstName: "User",
        lastName: "\(backendId)",
        dateOfBirth: "1990-01-01",
        handle: "user\(backendId)",
        companyId: 1,
        companyName: "Looped",
        bio: nil,
        profileImageURL: nil,
        isVerified: true,
        isAnonymous: false,
        createdAt: Date(),
        updatedAt: Date(),
        followerCount: 0,
        followingCount: 0,
        postsCount: 0,
        commentsCount: 0,
        likesReceivedCount: 0,
        showFollowerCount: true,
        hideAnonymousPosts: false,
        messagePermission: .all,
        viewerHasBlocked: false,
        viewerBlockedBy: false,
        displayCommunity: DisplayCommunity(
            id: displayCommunityId,
            name: "Community \(displayCommunityId)",
            shortName: nil,
            kind: .school,
            specializationType: nil
        ),
        displaySpecialization: nil
    )
}
