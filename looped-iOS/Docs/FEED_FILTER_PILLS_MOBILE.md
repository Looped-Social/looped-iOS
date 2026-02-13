# Mobile Feed Filter Pills (UI + Logic + API)

This doc describes the mobile feed filter pills flow shown in:
- `IMG_9098.PNG` (default feed filter row)
- `IMG_9099.PNG` (community search/filter overlay state)

Code sources:
- `Views/FeedView.swift`
- `Views/Shared/Feed/FeedTabs.swift`
- `ViewModels/FeedViewModel.swift`
- `Services/FeedService.swift`
- `Services/CommunityService.swift`

## 1) UI Structure

### Header stack
1. `FeedHeader` (logo + profile tap)
2. Top mode tabs:
   - `For You`
   - `Latest`
   - `Following`
3. Feed filter row:
   - Search icon button
   - `All Loops` pill
   - Community pills (horizontal scroll)

### Search-active state
When tapping the search icon:
1. Search text field (`Search communities`) + Cancel
2. Search helper/results card below field
3. Helper text when query is empty:
   - `Start typing to search.`
   - `Selecting a community filters your feed to posts from that community.`

## 2) Interaction Queue (Runtime Flow)

### Queue A: Initial load
1. `FeedView.task` triggers `viewModel.loadInitial()`.
2. `loadInitial()`:
   - If communities are empty: `loadFollowedCommunities()`
   - Then `loadPosts(reset: true)`
3. UI shows pills from `feedFilterCommunities` (followed + recent merged).
4. UI shows feed posts for current mode/community selection.

### Queue B: Select feed mode tab
1. User taps `For You` / `Latest` / `Following`.
2. `FeedTabs.onSelectMode` -> `FeedViewModel.selectFeedMode(mode)`.
3. ViewModel sets `feedMode`, clears new-post toast, reloads feed from page 1.
4. API request uses `mode` query param on `/v1/feed`.

### Queue C: Select `All Loops`
1. User taps `All Loops`.
2. `selectedCommunity` set to `nil`.
3. Reload feed page 1 with no `communityId` filter.

### Queue D: Select a community pill
1. User taps a community pill.
2. `selectedCommunity` is set.
3. Community is bumped into recent list (for pill ordering).
4. Reload feed page 1 with `communityId=<selected id>`.

### Queue E: Search communities
1. User taps search icon -> `isCommunitySearchActive = true`.
2. Query updates call `updateCommunitySearchQuery(query)`.
3. Debounce: 280ms task; previous search task is canceled.
4. If query trimmed length < 2: no API call, show helper text.
5. If length >= 2: call community search endpoint.
6. User taps search result:
   - resolve to `CommunitySummary` (existing followed item if present, otherwise synthesized from search item)
   - apply as selected community
   - dismiss search UI
   - reload feed with `communityId`

### Queue F: Pagination
1. Feed posts:
   - Triggered near tail item (`prefetchThreshold = 6`)
   - Request next page via `cursor`
2. Community pills:
   - Triggered when rendering last visible community pill
   - Requests next followed-communities page via `cursor`

## 3) Async/Queue Safety

- **Search task cancellation:** `communitySearchTask` is canceled on each query change and on dismiss.
- **Stale feed protection:** `activeFeedRequestId` prevents old responses from overwriting newer context.
- **Context lock:** response is applied only if both `feedMode` and `selectedCommunity` still match request context.
- **Skeleton delay:** 500ms delayed skeleton only if still loading and posts are still empty.
- **Pull-to-refresh:** disabled while search UI is active.

## 4) API Endpoints Used by This Feature

All calls are authenticated with Firebase Bearer token.

## 4.1 Get pill communities (followed list)

`GET /v1/me/followed/communities?limit=<int>&order=<relevant|recent>&cursor=<opaque?>`

Used by: filter pill row population and horizontal-load-more.

Example request:
```http
GET /v1/me/followed/communities?limit=50&order=relevant
Authorization: Bearer <firebase_jwt>
```

Example response:
```json
{
  "items": [
    {
      "id": 123,
      "name": "University of North Carolina",
      "short_name": "UNC",
      "kind": "school",
      "member_count": 4210,
      "is_pinned": false,
      "sort_order": null,
      "can_post": true,
      "is_joined": null
    }
  ],
  "next_cursor": "opaque-cursor"
}
```

## 4.2 Get feed posts (mode + optional community filter)

`GET /v1/feed?limit=<int>&mode=<for_you|new|following>&communityId=<int?>&cursor=<opaque?>`

Used by:
- initial feed load
- tab changes
- `All Loops` / community pill selection
- feed pagination
- new-post polling checks

Example request (all communities, For You):
```http
GET /v1/feed?limit=20&mode=for_you
Authorization: Bearer <firebase_jwt>
```

Example request (specific community in Following tab):
```http
GET /v1/feed?limit=20&mode=following&communityId=123
Authorization: Bearer <firebase_jwt>
```

Example response:
```json
{
  "items": [
    {
      "id": 101,
      "author_id": 12,
      "author_display_name": "John Smith",
      "author_handle": "johnsmith",
      "community_id": 123,
      "community_name": "Costco",
      "community_short_name": "costco",
      "community_kind": "company",
      "content": "$1.99 lunch making $30 an hour...",
      "likes_count": 5,
      "comments_count": 2,
      "share_count": 0,
      "user_liked": false,
      "is_saved": false,
      "created_at": "2026-02-10T15:20:00Z"
    }
  ],
  "next_cursor": "opaque-cursor"
}
```

## 4.3 Search communities (search mode)

`GET /v1/communities/search?query=<string>&limit=<int>&kind=<optional>&cursor=<opaque?>`

Used by: search sheet in filter UI.

Current app behavior:
- query is trimmed
- minimum length is 2
- `limit = 25`
- `kind = nil` (no kind filter currently applied)

Example request:
```http
GET /v1/communities/search?query=unc&limit=25
Authorization: Bearer <firebase_jwt>
```

Example response:
```json
{
  "items": [
    {
      "id": 123,
      "name": "University of North Carolina",
      "short_name": "UNC",
      "description": "School community",
      "kind": "school",
      "specialization_type": null,
      "member_count": 4210,
      "image_url": "https://...",
      "is_following": true,
      "is_joined": null
    }
  ],
  "next_cursor": "opaque-cursor"
}
```

## 5) Client-Side State/Persistence Used by Filter Pills

`FeedViewModel` persists filter context in `UserDefaults`:
- `feedActiveCommunityId`
- `feedRecentCommunities` (JSON array)
- `feedRecentCommunity*` fallback keys
- `lastSelectedCommunityId`

Behavior:
- On app start, recent communities are restored and merged into the front of pill list.
- Followed communities fetched from backend are used to normalize recent entries.

## 6) UI Copy + States (Search Card)

Search helper/result card states:
1. Error -> server/client message
2. Loading -> spinner
3. Empty query -> helper copy
4. 1-character query -> `Type at least 2 characters.`
5. No results -> `No matches found.`
6. Results list -> tap row to apply filter

## 7) Known Constraints

- Filtering is server-side via `/v1/feed` query params (`mode`, `communityId`), not client-side post filtering.
- Search only finds communities; selecting one filters feed and exits search.
- Pull-to-refresh is intentionally disabled while search UI is open.
