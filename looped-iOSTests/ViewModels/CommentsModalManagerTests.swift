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
    func resolvedAuthorName_prefersNameThenHandleWhenDisplayNameMissing() {
        let withName = Comment(dto: makeCommentDTO(
            id: 301,
            parentId: nil,
            name: "Taylor Rivera",
            displayName: nil,
            username: nil,
            handle: nil,
            isAnonymous: false
        ))
        #expect(withName.resolvedAuthorName == "Taylor Rivera")

        let withHandle = Comment(dto: makeCommentDTO(
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
}

private func makeComment(backendId: Int, parentId: Int?, displayName: String?) -> Comment {
    Comment(
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
