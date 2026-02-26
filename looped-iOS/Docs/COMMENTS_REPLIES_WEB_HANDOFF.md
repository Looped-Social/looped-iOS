# Comments Replies Handoff (Web)

This doc describes how comments + replies are wired in iOS today, with a web-focused contract for parity.

Primary sources:
- `Services/CommentsService.swift`
- `Models/API/CommentDTOs.swift`
- `Models/Comment.swift`
- `ViewModels/CommentsModalManager.swift`
- `Views/CommentsView.swift`
- `Views/Shared/Feed/CommentRow.swift`
- `Views/Shared/Core/LoopedFonts.swift`
- `Views/Shared/Core/LoopedColors.swift`

## 1) Current Behavior (Important)

- iOS **does support replying to a reply**: tapping Reply on any comment sets `parentId` to that comment’s `id`.
- The main iOS limitation is **styling/indentation**, not the API:
  - Visual styling is clamped to 2 tiers (top-level style vs reply style).
  - Indentation only happens for the first reply level; deeper descendants render with reply styling and no extra indent.

## 2) Endpoints Web Should Use

All endpoints below are what iOS uses today.

1. List comments for a post
- `GET /v1/posts/{postId}/comments?limit=<int>&cursor=<opaque?>`
- iOS page size: `20`

2. List replies for a comment
- `GET /v1/comments/{commentId}/replies?limit=<int>&cursor=<opaque?>`
- iOS page size: `20`

3. Create top-level comment or reply
- `POST /v1/posts/{postId}/comments`
- Body:
```json
{
  "content": "text",
  "parentId": 123,
  "mediaAssetId": null
}
```
- For a top-level comment: send `parentId: null`.
- For a reply (including reply-to-reply): send `parentId: <the comment id you are replying to>`.

4. Like/unlike comment
- `POST /v1/comments/{commentId}/like`
- `DELETE /v1/comments/{commentId}/like`

5. Optional public-read fallback used by iOS
- `GET /v1/public/posts/{postId}/comments`
- `GET /v1/public/comments/{commentId}/replies`
- iOS tries these on auth-restricted reads (or empty first-page edge case) when allowed.

## 3) Payload Fields That Matter for Replies

From `CommentDTO`:
- `id`
- `postId`
- `parentId`
- `content`
- `likesCount`
- `replyCount`
- `totalReplyCount` (or `descendantReplyCount` / `threadReplyCount` fallback)
- `userLiked`
- `likedByCreator`
- `isDeleted`
- `isUnderReview`
- `createdAt`
- `author.*` fields

Reply count semantics in iOS model:
- Effective thread count is `totalReplyCount ?? descendantReplyCount ?? threadReplyCount ?? replyCount`.

## 4) iOS Threading Behavior (for Web Parity)

1. Partitioning:
- `parentId == null` -> top-level list
- `parentId != null` -> grouped under `replyThreads[parentId]`

2. Expand behavior:
- First expand always performs authoritative fetch from `/v1/comments/{id}/replies` (even if inline replies were present).

3. Pagination:
- Cursor-based for both comments and replies.
- “View replies (N)” uses backend reply counts when present; otherwise loaded reply length.

4. Nesting style clamp:
- Reply rows render with `nestingLevel: min(nestingLevel + 1, 1)`.
- Result: only two visual styles exist (top-level style and reply style).
 - Indentation is only applied for replies directly under a top-level comment; deeper descendants do not get extra indent.

## 5) Styling Contract (Web)

Use Looped tokens only.

Typography:
- Top-level comment:
  - body `loopedCommentsBody` (16)
  - author `loopedCommentsAuthor` (16)
  - meta `loopedCommentsMeta` (13)
  - meta strong `loopedCommentsMetaStrong` (13)
  - action `loopedCommentsAction` (13)
- Reply:
  - body `loopedCommentsReplyBody` (15)
  - author `loopedCommentsReplyAuthor` (15)
  - meta `loopedCommentsReplyMeta` (12)
  - meta strong `loopedCommentsReplyMetaStrong` (12)
  - action `loopedCommentsReplyAction` (12)

Layout sizing:
- Avatar size: top-level `40`, reply `32`
- Vertical row padding: top-level `14`, reply `10`
- Reply block inset under top-level row only (`profileSize - 8`)
- Like icon size: top-level `20`, reply `16`

Color tokens used in replies/comments UI:
- Text: `loopedTextPrimary`, `loopedTextSecondary`, `loopedTextStrong`
- Accent: `loopedPrimary`
- Composer background: `loopedMessageMutedColor`
- Surface: `loopedBackground`
- Error: `loopedError`

## 6) Composer Behavior to Match

- Selecting Reply sets a reply target and shows: `Replying to <name>`.
- Composer placeholder remains generic (`Add a comment...`) even in reply mode.
- Posting chooses `parentId` from current reply target; no reply target means top-level comment.

## 7) Web Implementation Checklist (Now)

1. Allow Reply on any comment (including replies) unless deleted/locked.
2. Create replies via `POST /v1/posts/{postId}/comments` with `parentId=<target-comment-id>`.
3. Fetch replies from `/v1/comments/{commentId}/replies` with cursor pagination (works for any comment id).
4. Keep two-tier styling only (comment + reply); do not introduce a third visual tier yet.
5. Use backend reply count fields in this order:
   - `totalReplyCount`
   - `descendantReplyCount`
   - `threadReplyCount`
   - `replyCount`
