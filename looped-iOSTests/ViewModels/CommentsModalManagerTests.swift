import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct CommentsModalManagerTests {

    @Test
    func partitionCommentsForDisplay_movesRepliesOutOfRootList() {
        let root = makeComment(backendId: 11, parentId: nil, displayName: "Root Author")
        let reply = makeComment(backendId: 12, parentId: 11, displayName: "Reply Author")

        let partitioned = CommentsModalManager.partitionCommentsForDisplay([root, reply])

        #expect(partitioned.topLevelComments.compactMap(\.backendId) == [11])
        #expect(partitioned.inlineRepliesByParentId[11]?.compactMap(\.backendId) == [12])
    }

    @Test
    func partitionCommentsForDisplay_deduplicatesRootAndRepliesByBackendId() {
        let root = makeComment(backendId: 101, parentId: nil, displayName: "Root")
        let duplicateRoot = makeComment(backendId: 101, parentId: nil, displayName: "Root duplicate")
        let reply = makeComment(backendId: 202, parentId: 101, displayName: "Reply")
        let duplicateReply = makeComment(backendId: 202, parentId: 101, displayName: "Reply duplicate")

        let partitioned = CommentsModalManager.partitionCommentsForDisplay([
            root,
            duplicateRoot,
            reply,
            duplicateReply
        ])

        #expect(partitioned.topLevelComments.compactMap(\.backendId) == [101])
        #expect(partitioned.inlineRepliesByParentId[101]?.compactMap(\.backendId) == [202])
    }

    @Test
    func partitionCommentsForDisplay_hidesDeletedTopLevelWithoutReplies() {
        let deleted = makeComment(
            backendId: 601,
            parentId: nil,
            displayName: "Deleted",
            replyCount: 0,
            isDeleted: true
        )

        let partitioned = CommentsModalManager.partitionCommentsForDisplay([deleted])

        #expect(partitioned.topLevelComments.isEmpty)
    }

    @Test
    func resolvedAuthorName_prefersNameThenHandleWhenDisplayNameMissing() {
        let withName = looped_iOS.Comment(dto: makeCommentDTO(
            id: 301,
            parentId: nil,
            name: "Taylor Rivera",
            displayName: nil,
            username: nil,
            handle: nil,
            isAnonymous: false
        ))
        #expect(withName.resolvedAuthorName == "Taylor Rivera")

        let withHandle = looped_iOS.Comment(dto: makeCommentDTO(
            id: 302,
            parentId: nil,
            name: nil,
            displayName: nil,
            username: nil,
            handle: "taylorr",
            isAnonymous: false
        ))
        #expect(withHandle.resolvedAuthorName == "@taylorr")
    }

    @Test
    func deleteComment_removesTopLevelWhenNoReplies() async {
        let commentsService = MockCommentsService()
        let manager = makeManager(commentsService: commentsService)
        await prepareManagerForPost(manager, postId: 99)

        let comment = makeComment(backendId: 401, parentId: nil, displayName: "Root", replyCount: 0)
        manager.currentComments = [comment]

        await manager.deleteComment(comment)

        #expect(manager.currentComments.isEmpty)
    }

    @Test
    func deleteComment_keepsTopLevelTombstoneWhenRepliesExist() async {
        let commentsService = MockCommentsService()
        let manager = makeManager(commentsService: commentsService)
        await prepareManagerForPost(manager, postId: 100)

        let comment = makeComment(backendId: 402, parentId: nil, displayName: "Root", replyCount: 2)
        manager.currentComments = [comment]

        await manager.deleteComment(comment)

        #expect(manager.currentComments.count == 1)
        #expect(manager.currentComments[0].isDeleted)
    }

    @Test
    func deleteComment_removesReplyWhenNoNestedRepliesAndUpdatesParentCount() async {
        let commentsService = MockCommentsService()
        let manager = makeManager(commentsService: commentsService)
        await prepareManagerForPost(manager, postId: 101)

        let parent = makeComment(backendId: 501, parentId: nil, displayName: "Parent", replyCount: 1)
        let reply = makeComment(backendId: 502, parentId: 501, displayName: "Reply", replyCount: 0)
        manager.currentComments = [parent]
        manager.replyThreads[501] = ReplyThreadState(replies: [reply], isExpanded: true)

        await manager.deleteComment(reply)

        #expect(manager.replyThreads[501]?.replies.isEmpty == true)
        #expect(manager.currentComments.first?.replyCount == 0)
    }
}

private func makeComment(
    backendId: Int,
    parentId: Int?,
    displayName: String?,
    replyCount: Int = 0,
    isDeleted: Bool = false
) -> looped_iOS.Comment {
    looped_iOS.Comment(
        id: UUID.fromBackendId(backendId),
        backendId: backendId,
        postId: UUID.fromBackendId(1),
        postBackendId: 1,
        content: "Comment \(backendId)",
        authorId: UUID.fromBackendId(backendId + 1_000),
        authorBackendId: backendId + 1_000,
        authorDisplayName: displayName,
        authorHandle: "user\(backendId)",
        company: "Looped",
        isAnonymous: false,
        isDeleted: isDeleted,
        replyCount: replyCount,
        replyToCommentId: parentId.map(UUID.fromBackendId),
        replyToBackendId: parentId
    )
}

private func makeCommentDTO(
    id: Int,
    parentId: Int?,
    name: String?,
    displayName: String?,
    username: String?,
    handle: String?,
    isAnonymous: Bool
) -> CommentDTO {
    CommentDTO(
        id: id,
        postId: 1,
        parentId: parentId,
        author: CommentAuthorDTO(
            id: 42,
            principalId: 42,
            isAnonymous: isAnonymous,
            name: name,
            displayName: displayName,
            username: username,
            handle: handle,
            companyId: 5,
            profileImageUrl: nil
        ),
        isAnonymous: isAnonymous,
        authorIsAnonymous: isAnonymous,
        authorPrincipalId: 42,
        content: "Body",
        mediaAssetId: nil,
        likesCount: 0,
        replyCount: 0,
        userLiked: false,
        likedByCreator: false,
        isDeleted: false,
        isUnderReview: false,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

@MainActor
private func makeManager(commentsService: MockCommentsService) -> CommentsModalManager {
    CommentsModalManager(
        commentsService: commentsService,
        communityService: MockCommunityService(),
        mediaService: MockMediaService()
    )
}

@MainActor
private func prepareManagerForPost(_ manager: CommentsModalManager, postId: Int) async {
    manager.showComments(for: TestFixtures.post(backendId: postId))
    try? await Task.sleep(nanoseconds: 20_000_000)
}

final class MockCommentsService: CommentsServiceProtocol {
    var fetchCommentsResult = CommentPage(comments: [], nextCursor: nil)
    var fetchRepliesResult = CommentPage(comments: [], nextCursor: nil)

    func fetchComments(postId: Int, communityId: Int?, limit: Int, cursor: String?) async throws -> CommentPage {
        fetchCommentsResult
    }

    func fetchReplies(commentId: Int, communityId: Int?, limit: Int, cursor: String?) async throws -> CommentPage {
        fetchRepliesResult
    }

    func createComment(postId: Int, communityId: Int?, content: String, parentId: Int?, mediaAssetId: Int?) async throws -> looped_iOS.Comment {
        throw TestError.unimplemented(#function)
    }

    func editComment(commentId: Int, communityId: Int?, content: String, asAnon: Bool) async throws -> looped_iOS.Comment {
        throw TestError.unimplemented(#function)
    }

    func deleteComment(commentId: Int, communityId: Int?, asAnon: Bool) async throws -> CommentDeleteResponse {
        CommentDeleteResponse(commentId: commentId, deleted: true)
    }

    func likeComment(commentId: Int, communityId: Int?) async throws -> CommentLikeResponse {
        throw TestError.unimplemented(#function)
    }

    func unlikeComment(commentId: Int, communityId: Int?) async throws -> CommentLikeResponse {
        throw TestError.unimplemented(#function)
    }
}
