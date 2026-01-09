# Codex Handoff – Wiring Progress

## What’s Live (ready today)
- **Authentication:** Firebase email/password + Google + Apple. Tokens automatically pulled via FirebaseAuth token provider; API client adds `Authorization: Bearer <Firebase ID token>` on every call.
- **Identity:** `/v1/me` wired into `UserService` + `AuthViewModel`. Signed-in user data (display name, @handle, company, bio) is propagated via `AuthViewModel.currentUser`.
- **Feed & Posts:** `/v1/feed`, `/v1/posts`, `/v1/posts/{id}/like` (POST/DELETE) live. DTOs map backend payloads into `Post`, including `backendId`, `authorBackendId`, `isSaved`, and per-viewer `user_liked` for the heart state. Feed pagination with cursor + pull-to-refresh works.
- **Bookmarks:** Feed cards call `/v1/posts/{id}/save` / DELETE, update local state, and notify collection view models.
- **Collections (Liked/Saved):** `CollectionPostsViewModel` hits `/v1/posts/liked` and `/v1/posts/saved`, with paging, refresh, and error states. Liked/Saved screens in the drawer are fully real now.
- **Profile (self):** `ProfileViewModel` pulls profile info from `/v1/me` and posts via `/v1/users/{id}/posts`. UI shows placeholders (“Add your bio…”) while loading but no longer uses mock data.
- **Other user profiles:** `UserProfileView` now fetches `/v1/users/{id}` and `/v1/users/{id}/posts` through `UserProfileViewModel` + `CollectionPostsViewModel`. `MockUserProfiles` was removed.
- **People search:** `SearchResultsViewModel` calls `/v1/users/search` for people results; New Message search uses the same endpoint to start DMs.
- **Loop/hashtag search:** Search results now call `/v1/loops/search` and `/v1/hashtags/search` with cursor paging (treat `next_cursor` as opaque; just pass it back as `cursor`).
- **Onboarding org + verification:** Company/school picker uses `/v1/communities/search` (`kind=company|school`) and email verification uses `/v1/communities/{id}/domains` + `/v1/communities/{id}/verification/start|finish`.
- **Messaging (polling):** Conversations/channels/messages are wired to `/v1/conversations` and `/v1/channels` endpoints. Mock conversations/messages removed; ChatView/ConversationRow use backend IDs.
- **Notifications:** wired to `/v1/notifications` + `/v1/notifications/{id}/read` (polling). Mock notifications removed.
- **Comments:** Feed/post comments now hit `/v1/posts/{id}/comments` (list/create) and `/v1/comments/{id}/like`; replies load via `/v1/comments/{id}/replies`. Counts come from backend.
- **Docs:** `Docs/API_REFERENCE.md` documents identity, profile, collections, comments, and discovery endpoints per backend spec.

## What’s Still Mocked / To Do
1. **WebSocket realtime:** `WebSocketService` still mocky; messaging is HTTP polling only.
2. **Profile tabs:** Replies/Saved tabs still show “Coming soon.” Add endpoints for replies/comments history per user as needed.
3. **Post interactions beyond like/save:** Share counts now read from backend `share_count`, but there’s no share endpoint/action wired.

## Suggested Next Steps for the Next Codex
1. **Comments polish**
   - Consider showing reply counts if backend exposes them; add toasts/error UI for comment failures.

2. **Notifications polish**
   - Add UI for mark-read (already API-wired) and surface errors; consider pagination in the UI if needed.

3. **Realtime plan**
   - Decide on WebSocket strategy for messaging/notifications and update `WebSocketService` accordingly (currently mock).

4. **Optional polish**
   - Skeleton loaders for Profile/Feed if desired.
   - Surface errors/toasts when save/unsave requests fail.

By finishing the above, the app will be fully wired to the backend for core feed/profile/bookmark flows. Remaining work then centers on messaging/search/notifications and realtime features.
