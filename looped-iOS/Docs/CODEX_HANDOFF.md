# Codex Handoff – Wiring Progress

## What’s Live (ready today)
- **Authentication:** Firebase email/password + Google + Apple. Tokens automatically pulled via FirebaseAuth token provider; API client adds `Authorization: Bearer <Firebase ID token>` on every call.
- **Identity:** `/v1/me` wired into `UserService` + `AuthViewModel`. Signed-in user data (display name, @handle, company, bio) is propagated via `AuthViewModel.currentUser`.
- **Feed & Posts:** `/v1/feed`, `/v1/posts`, `/v1/posts/{id}/like` live. DTOs map backend payloads into `Post`, including `backendId`, `authorBackendId`, and `isSaved`. Feed pagination with cursor + pull-to-refresh works.
- **Bookmarks:** Feed cards call `/v1/posts/{id}/save` / DELETE, update local state, and notify collection view models.
- **Collections (Liked/Saved):** `CollectionPostsViewModel` hits `/v1/posts/liked` and `/v1/posts/saved`, with paging, refresh, and error states. Liked/Saved screens in the drawer are fully real now.
- **Profile (self):** `ProfileViewModel` pulls profile info from `/v1/me` and posts via `/v1/users/{id}/posts`. UI shows placeholders (“Add your bio…”) while loading but no longer uses mock data.
- **Other user profiles:** `UserProfileView` now fetches `/v1/users/{id}` and `/v1/users/{id}/posts` through `UserProfileViewModel` + `CollectionPostsViewModel`. `MockUserProfiles` was removed.
- **Docs:** `Docs/API_REFERENCE.md` documents identity, profile, and collections endpoints per backend spec.

## What’s Still Mocked / To Do
1. **User discovery/search UX:** Search results, “new message” pickers, and chat member lists still use placeholder content because there’s no backend people search/directory yet. Wire to real search/list endpoints once available so profile links can always launch the real `UserProfileView`.
2. **Messaging/Search/Notifications:** still point at `MockConversations`, `MockMessages`, etc. Future wiring needed to Java backend endpoints/WebSocket.
3. **Post interactions beyond like/save:** share counts, comment counts still use `MockPosts` helpers. Replace with real count fields or hide until backend provides them.
4. **Followers/Following stats:** Profile pills currently show placeholder numbers (0). Once backend exposes these counts, map them in `UserProfile` / UI.
5. **Replies/Saved tabs on profile:** still display “Coming soon.” Need endpoints for replies/comments history and saved posts per user.
6. **User settings save flow:** update endpoints exist (`/users/me` PUT) but the Settings screen’s “Save changes” button is still a stub; wire it up.
7. **WebSocket realtime:** `WebSocketService` currently uses mock data. Eventually connect to backend WS for messaging/notifications.

## Suggested Next Steps for the Next Codex
1. **Wire user discovery**
   - Connect Search/New Message/Chat member lists to a real people search/list endpoint and feed backend user IDs through conversations so profile links can launch the real `UserProfileView`.

2. **Add save/unsave buttons wherever posts appear** (e.g., profile feed, grid view) using the new save APIs.

3. **Plan for messaging/search**
   - Inventory existing services/views that still depend on `MockMessages` and outline backend endpoints needed (channels list, conversation list, send message, etc.).

4. **Optional polish**
   - Skeleton loaders for Profile/Feed if desired.
   - Surface errors/toasts when save/unsave requests fail.

By finishing the above, the app will be fully wired to the backend for core feed/profile/bookmark flows. Remaining work then centers on messaging/search/notifications and realtime features.
