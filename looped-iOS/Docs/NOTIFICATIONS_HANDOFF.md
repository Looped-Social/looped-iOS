# Notifications Handoff (iOS Contract + Gaps)

This doc captures what iOS currently supports for notifications, what payload shape it expects from backend, and where issues like verification reminders, blank "liked your post", or broken tap navigation come from.

Code sources:
- `Services/NotificationService.swift`
- `Models/Notification.swift`
- `Models/API/NotificationDTOs.swift`
- `ViewModels/NotificationsViewModel.swift`
- `Views/NotificationsView.swift`
- `DeepLinkRouter.swift`
- `ContentView.swift`
- `looped_iOSApp.swift`

## 1) Endpoints iOS Uses

1. `GET /v1/notifications?limit=<int>&cursor=<opaque?>`
- Returns paged notification list.
- iOS defaults `limit=50`.

2. `POST /v1/notifications/{id}/read`
- Called when tapping an item and also from push payload handling if `notification_id` exists.

3. `GET /v1/notifications/preferences`
4. `PUT /v1/notifications/preferences`
- Settings screen toggles for delivery/type preferences.

## 2) Notification Types iOS Knows

iOS `NotificationType` enum currently supports:
- `like`
- `comment`
- `reply`
- `mention`
- `follow`
- `post_from_followed`
- `message_request`
- `announcement`
- `system`
- `loopInvite`
- `groupInvite`
- `repost`

If backend sends an unknown `type`, iOS maps it to `system` (not dropped).

## 3) Payload Fields iOS Reads

From `payload`, iOS reads:
- actor: `actor_user_id`, `actor_anon_profile_id`, `actor_is_anonymous`, `actor_display_name`, `actor_profile_image_url`
- targets: `post_id`, `comment_id`
- text: `title`, `body`, `context`
- link: `deeplink`, `action_deeplink`
- verification metadata: `category`, `kind`, `status`, `method`, `company_id`, `community_id`, `community_name`, `expires_at`, `days_remaining`, `event_key`
- announcement metadata: `years`

Notes:
- `action_deeplink` falls back to `deeplink` if missing.
- `target_content` is not currently mapped from API payload; preview card text is primarily `body`.

## 4) Verification Notifications (Current iOS Behavior)

iOS does not require a dedicated `type=verification_*`.
It renders verification copy when either is true:
1. `payload.category == "verification"`
2. `payload.kind == "community_verification"` or `"user_verification"`

Then it uses `payload.status` for title/body behavior:
- `approved`
- `rejected`
- `expiring`
- `expired`

So verification confirmations/reminders work best when backend sends:
- `type: "system"` (or `announcement`)
- `payload.category: "verification"`
- `payload.kind: "community_verification"` (or `user_verification`)
- `payload.status: approved|expiring|expired|rejected`
- optional `community_name`, `days_remaining`, `title`, `body`

If backend sends a new custom `type` for verification, iOS will still show it as `system` as long as those verification fields are present.

## 5) Tap Navigation Contract

### In-app notification list tap

1. `like/comment/reply/mention/repost`
- Preferred route: `payload.post_id`
- For comment/reply: if `comment_id` exists, iOS opens comment focus.
- Fallback: `deeplink` then `action_deeplink`.
- If none exists: toast "This post isn't available right now."

2. `follow`
- Preferred route: `actor_user_id` or `actor_anon_profile_id`
- Fallback: deeplink.

3. `post_from_followed`
- Preferred route: `post_id`
- Fallback: deeplink.

4. `message_request`
- Deeplink only (else "not available yet" info toast).

5. `announcement/system`
- In list, iOS opens local detail screen and marks read.
- It does not deep-link on list tap today.

### Push notification tap

Push tap handling uses payload keys:
- `notification_id` -> mark-read API call
- `deeplink` -> navigation

If `deeplink` is missing, push tap marks read (if possible) but cannot navigate.

## 6) Deep Link Formats iOS Accepts

Supported `looped://`:
- `looped://post/{postId}`
- `looped://comment/{commentId}?post_id={postId}`
- `looped://user/{userId}` (optional `?anon=true`)
- `looped://announcement/{id}`
- `looped://conversations/{conversationId}`
- `looped://channels/{channelId}`

Supported universal links:
- `https://mylooped.app/p/{postId}`
- `https://mylooped.app/u/{slug}`

Important:
- `announcement` route currently expects a numeric path segment (`/announcement/{id}`), even though id is not used by destination.
- For comment deep links, missing `post_id` cannot open target post and drops user on notifications tab.

## 7) Why "Blank liked your post" Can Happen

iOS notification text is built as `{actorName} liked your post`.
iOS attempts fallback actor names (`Someone`, `Anonymous`) when actor name is missing, but UI can still look wrong if backend sends malformed actor data.

Backend-side guardrails recommended:
1. If actor is unknown, send `null` for `actor_display_name` (not empty/invisible string).
2. For non-anonymous actor notifications, include `actor_user_id`.
3. For anonymous actor notifications, include `actor_anon_profile_id` and `actor_is_anonymous=true`.
4. Always include `post_id` for like/comment/reply/mention/repost notifications.

## 8) Backend Contract Checklist (Recommended)

1. Keep canonical notification `type` values above (or include verification metadata when adding new types).
2. For post-targeted events, always include `post_id`.
3. For comment/reply focus, include `comment_id` too.
4. For tap reliability, include `deeplink` as fallback even when IDs are present.
5. Push payload should include both:
- `notification_id`
- `deeplink`
6. For verification reminders/confirmations, send:
- `category=verification`
- `kind=community_verification|user_verification`
- `status=approved|expiring|expired|rejected`
- `community_name` and `days_remaining` when relevant.

## 9) QA Matrix (Backend + iOS)

1. Like notification with `post_id` -> tap opens target post.
2. Comment/reply with `post_id + comment_id` -> tap opens post and focuses comment.
3. Verification approved + verification fields -> shows verification title/body (not generic "System notification").
4. Verification expiring with `days_remaining` -> shows "expires in X days" copy.
5. Notification with missing IDs but valid deeplink -> still navigates.
6. Push payload with `notification_id + deeplink` -> marks read and navigates.
7. Push payload missing deeplink -> marks read but no navigation (expected).

## 10) Known iOS Gaps (Not Backend Outage)

1. Verification does not have a dedicated notification settings toggle type today.
- It is rendered through `system/announcement` + verification metadata fields.

2. `announcement/system` list taps open local detail UI, not deeplink routing.
- Push taps still deeplink if payload has `deeplink`.

3. Invite type raw values are camelCase in iOS (`loopInvite`, `groupInvite`).
- If backend sends snake_case invite types, iOS currently falls back to `system`.

4. Notification preview text uses `body` (or verification fallback copy).
- `target_content` is not currently parsed into `targetContent`.
