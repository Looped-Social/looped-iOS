import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct UnderReviewViewModelTests {

    @Test
    func loadInitial_regularMode_fetchesMyContentAndFiltersUnderReview() async {
        let service = MockFeedService()
        service.fetchMyContentHandler = { _, _, _ in
            UserContentPage(
                items: [
                    makeUnderReviewItem(postId: 11, isAnonymous: false, anonProfileId: nil, isUnderReview: true),
                    makeUnderReviewItem(postId: 12, isAnonymous: false, anonProfileId: nil, isUnderReview: false)
                ],
                nextCursor: nil
            )
        }

        let viewModel = UnderReviewViewModel(feedService: service)
        await viewModel.loadInitial(fallbackUserId: 5, isAnonymousMode: false, anonProfileId: nil)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.posts.map(\.backendId) == [11])
        #expect(service.fetchMyContentCalls.count == 1)
        #expect(service.fetchAnonContentCalls.isEmpty)
    }

    @Test
    func loadInitial_anonymousMode_fetchesAnonContentOnly() async {
        let service = MockFeedService()
        service.fetchAnonContentHandler = { anonProfileId, _, _, _ in
            #expect(anonProfileId == 9001)
            return UserContentPage(
                items: [
                    makeUnderReviewItem(postId: 21, isAnonymous: true, anonProfileId: 9001, isUnderReview: true),
                    makeUnderReviewItem(postId: 22, isAnonymous: true, anonProfileId: 9001, isUnderReview: false)
                ],
                nextCursor: nil
            )
        }
        service.fetchMyContentHandler = { _, _, _ in
            Issue.record("Regular content endpoint should not be used in anonymous mode")
            return UserContentPage(items: [], nextCursor: nil)
        }

        let viewModel = UnderReviewViewModel(feedService: service)
        await viewModel.loadInitial(fallbackUserId: 5, isAnonymousMode: true, anonProfileId: 9001)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.posts.map(\.backendId) == [21])
        #expect(service.fetchAnonContentCalls.count == 1)
        #expect(service.fetchMyContentCalls.isEmpty)
        #expect(service.fetchUserContentCalls.isEmpty)
    }

    @Test
    func loadInitial_anonymousMode_withoutIdentity_skipsNetworkAndClears() async {
        let service = MockFeedService()
        let viewModel = UnderReviewViewModel(feedService: service)

        await viewModel.loadInitial(
            fallbackUserId: 5,
            isAnonymousMode: true,
            anonProfileId: nil
        )

        #expect(viewModel.posts.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(service.fetchAnonContentCalls.isEmpty)
        #expect(service.fetchMyContentCalls.isEmpty)
        #expect(service.fetchUserContentCalls.isEmpty)
    }
}

private func makeUnderReviewItem(
    postId: Int,
    isAnonymous: Bool,
    anonProfileId: Int?,
    isUnderReview: Bool
) -> UserContentItem {
    let createdAt = Date()
    let post = Post(
        id: UUID.fromBackendId(postId),
        backendId: postId,
        authorBackendId: isAnonymous ? nil : 101,
        authorPrincipalId: 101,
        anonProfileId: anonProfileId,
        content: "Post \(postId)",
        authorId: UUID.fromBackendId(101),
        authorDisplayName: isAnonymous ? nil : "Author",
        authorHandle: isAnonymous ? "anonymous" : "author",
        company: "Looped",
        communityId: 1,
        communityName: "Looped",
        communityShortName: "LP",
        communityKind: .company,
        isAnonymous: isAnonymous,
        isUnderReview: isUnderReview,
        reactionCount: 0,
        commentsCount: 0,
        shareCount: 0,
        userReaction: nil,
        attachments: nil,
        isSaved: false,
        createdAt: createdAt,
        updatedAt: createdAt
    )
    return UserContentItem(id: "post-\(postId)", createdAt: createdAt, payload: .post(post))
}

