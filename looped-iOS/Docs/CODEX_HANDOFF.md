# Codex Handoff – Wiring Progress

## What’s Live (ready today)
- **Authentication:** Firebase email/password + Google + Apple. Tokens automatically pulled via FirebaseAuth token provider; API client adds `Authorization: Bearer <Firebase ID token>` on every call.
- **Identity:** `/v1/me` wired into `UserService` + `AuthViewModel`. Signed-in user data (display name, @handle, company, bio) is propagated via `AuthViewModel.currentUser`.
- **Feed & Posts:** `/v1/feed`, `/v1/posts`, `/v1/posts/{id}/like` live. DTOs map backend payloads into `Post`, including `backendId`, `authorBackendId`, and `isSaved`. Feed pagination with cursor + pull-to-refresh works.
- **Bookmarks:** Feed cards call `/v1/posts/{id}/save` / DELETE, update local state, and notify collection view models.
- **Collections (Liked/Saved):** `CollectionPostsViewModel` hits `/v1/posts/liked` and `/v1/posts/saved`, with paging, refresh, and error states. Liked/Saved screens in the drawer are fully real now.
- **Profile (self):** `ProfileViewModel` pulls profile info from `/v1/me` and posts via `/v1/users/{id}/posts`. UI shows placeholders (“Add your bio…”) while loading but no longer uses mock data.
- **Other user profiles:** `UserProfileView` now fetches `/v1/users/{id}` and `/v1/users/{id}/posts` through `UserProfileViewModel` + `CollectionPostsViewModel`. `MockUserProfiles` was removed.
- **People search:** `SearchResultsViewModel` calls `/v1/users/search` for people results; New Message search uses the same endpoint to start DMs.
- **Messaging (polling):** Conversations/channels/messages are wired to `/v1/conversations` and `/v1/channels` endpoints. Mock conversations/messages removed; ChatView/ConversationRow use backend IDs.
- **Notifications:** wired to `/v1/notifications` + `/v1/notifications/{id}/read` (polling). Mock notifications removed.
- **Docs:** `Docs/API_REFERENCE.md` documents identity, profile, and collections endpoints per backend spec.

## What’s Still Mocked / To Do
1. **Comment counts/threads:** Feed/comment counts still come from mock helpers; profile comments list is wired, but feed counts aren’t. Add backend fields or hide until available.
2. **Search loops/hashtags & static content:** loops/hashtags still use `MockSearchContent` (people search is real).
3. **WebSocket realtime:** `WebSocketService` still mocky; messaging is HTTP polling only.
4. **Followers/Following stats:** Profile pills still default to 0 unless backend fields provided.
5. **Profile tabs:** Replies/Saved tabs still show “Coming soon.” Add endpoints for replies/comments history per user as needed.
6. **Post interactions beyond like/save:** share/comment counts rely on `MockPosts` helpers; map backend counts when available.

## Suggested Next Steps for the Next Codex
1. **Feed/interactions cleanup**
   - Replace mock comment/share counts in feed cards with backend fields (or hide until available).

2. **Notifications polish**
   - Add UI for mark-read (already API-wired) and surface errors; consider pagination in the UI if needed.

3. **Realtime plan**
   - Decide on WebSocket strategy for messaging/notifications and update `WebSocketService` accordingly (currently mock).

4. **Optional polish**
   - Skeleton loaders for Profile/Feed if desired.
   - Surface errors/toasts when save/unsave requests fail.

By finishing the above, the app will be fully wired to the backend for core feed/profile/bookmark flows. Remaining work then centers on messaging/search/notifications and realtime features.
