# Looped API — iOS Integration Reference (MVP)

This document is a concise, copy‑pasteable reference for the iOS client (and tools like Codex) covering auth, headers, pagination, request/response shapes, and the MVP database schema. It reflects the running Spring Boot API in this repo.

## Base URL and Auth

- Base URL (prod/stage): `https://api.<your-domain>`
- Local dev: `http://localhost:8080`
- Auth: Firebase ID token on every request
  - Header: `Authorization: Bearer <FirebaseIDToken>`
  - Backend enforces issuer/audience and validates via JWKS.

Environment variables (set in ECS via SSM/Secrets)
- `AUTH_ISSUER = https://securetoken.google.com/<FIREBASE_PROJECT_ID>`
- `AUTH_AUDIENCE = <FIREBASE_PROJECT_ID>`
- `AUTH_JWKS_URI = https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`

## Conventions

- Content-Type: `application/json` for request/response bodies
- Idempotency:
  - Required header for `POST /v1/posts` and recommended for `POST /v1/devices`:
    - `Idempotency-Key: <client-generated-uuid>`
- Pagination:
  - Cursor-based, parameter `cursor` (opaque string)
  - `GET /v1/feed?limit=...&cursor=...`
  - Cursor encodes the last item of the previous page; supply it to fetch the next page.
- Errors (JSON):
  - `{ "error": "string", "message": "optional detail" }`
- Health (no auth required):
  - `GET /health` → `ok`
  - `GET /actuator/health` → `{ "status": "UP" }`

## Endpoints

### Identity

GET /v1/me
- Auth required; returns identity from the token plus provisioned user (if present)
- 200 OK
```
{
  "sub": "firebase-uid",
  "iss": "https://securetoken.google.com/<PROJECT_ID>",
  "aud": ["<PROJECT_ID>"],
  "email": "optional@example.com",
  "provisioned": true,
  "user": {
    "id": 123,
    "handle": "erin",
    "company_id": 5,
    "verification": {
      "method": "email|video|thirdparty",
      "verified": true,
      "verified_at": "2024-01-02T03:04:05Z"
    },
    "profile": {
      "display_name": "Erin",
      "username": "erin",
      "bio": "PM @ Looped",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-05T00:00:00Z"
    }
  }
}
```

GET /v1/users/{id}
- Auth required, same-company scope and caller must be provisioned
- 200 OK with the same payload shape as `/v1/me.user`
- 403 if cross-company, 409 if caller isn’t provisioned, 404 if user not found

PUT /v1/users/me (alias: /users/me)
- Auth required
- Request body: `{ "displayName": "optional", "bio": "optional", "isAnonymous": <bool> }`
- Response: same shape as `/v1/me.user` with stats fields (`follower_count`, `following_count`, `posts_count`, `comments_count`) and `profile_image_url` when available

GET /v1/users/{id}/posts?limit=&cursor=
- Paginated posts authored by `{id}` (ASC by created_at/id)
- Response: `{ "items": [post...], "next_cursor": "..." }`
- Same pagination + auth rules as `/v1/feed`

GET /v1/users/{id}/comments?limit=&cursor=
- Paginated comments/replies authored by `{id}`
- Response: `{ "items": [{ "id": 1, "post_id": 101, "content": "...", "created_at": "...", "parent_id": null }], "next_cursor": "..." }`
- Same pagination + auth rules as `/v1/feed`

### People Search / Directory

GET /v1/users/search?query=&limit=&cursor=
- Auth required, same-company scope; `query` required
- Response: `{ "items": [{ "id": 12, "handle": "erin", "username": "erin", "display_name": "Erin", "bio": "...", "company_id": 5, "profile_image_url": "..." }], "next_cursor": "..." }`

GET /v1/users?limit=&cursor=
- Auth required, same-company scope; default directory/suggestions with the same item shape as search

### Feed & Posts

GET /v1/feed?limit=<int>&cursor=<string>
- Auth required; returns posts for the caller’s company only
- 200 OK
```
{
  "items": [
    {
      "id": 101,
      "author_id": 12,
      "company_id": 5,
      "content": "hello",
      "media_asset_id": 77,          // nullable
      "likes_count": 3,
      "comments_count": 0,
      "share_count": 0,
      "created_at": "2024-01-02T03:04:05Z"
    }
  ],
  "next_cursor": "opaque-cursor"   // omitted on last page
}
```

POST /v1/posts
- Auth required; Idempotency-Key required
- Request
```
{ "content": "hello world", "mediaAssetId": 77 }    // mediaAssetId optional
```
- Responses
  - 201 Created (first time)
  - 200 OK (idempotent replay)
```
{ "id": 101, "content": "hello world", "media_asset_id": 77 }
```

GET /v1/posts/{id}
- Auth required; company‑scoped
- 200 OK
```
{
  "id": 101,
  "author_id": 12,
  "company_id": 5,
  "content": "hello",
  "media_asset_id": 77,     // nullable
  "likes_count": 3,
  "comments_count": 0,
  "share_count": 0,
  "created_at": "2024-01-02T03:04:05Z"
}
```
- 403 if cross‑company; 404 if not found

POST /v1/posts/{id}/like
- Auth required; idempotent per user/post
- Responses
  - 201 Created (first like)
  - 200 OK (already liked)
  - 403 forbidden (cross‑company); 404 not found
```
{ "post_id": 101, "likes_count": 4 }
```

### Comments

GET /v1/posts/{postId}/comments?limit=&cursor=
- Auth required; company‑scoped, paginated oldest-first
- 200 OK
```
{
  "items": [
    {
      "id": 1,
      "post_id": 101,
      "parent_id": null,
      "author": {
        "id": 12,
        "display_name": "Erin",
        "username": "erin",
        "handle": "erin",
        "company_id": 5,
        "profile_image_url": "https://..."
      },
      "is_anonymous": false,
      "content": "Nice post!",
      "likes_count": 3,
      "user_liked": true,          // for caller
      "liked_by_creator": false,   // post author liked
      "created_at": "2024-01-02T03:04:05Z"
    }
  ],
  "next_cursor": "opaque-cursor"
}
```

POST /v1/posts/{postId}/comments
- Auth required; body `{ "content": "text", "parentId": 123? }`
- 201 with the same payload shape as GET items
- 422 if parent belongs to another post, 404 if parent missing, 403 on cross-company, 409 if caller not provisioned

GET /v1/comments/{id}/replies?limit=&cursor=
- Auth required; replies for a comment, same payload/ordering/next_cursor rules

POST /v1/comments/{id}/like
- Auth required; 201 on first like otherwise 200
- Response: `{ "comment_id": 1, "likes_count": 4, "user_liked": true, "liked_by_creator": false }`

### Discovery

GET /v1/loops/search?query=&limit=&cursor=
- Auth required; same-company scope; 422 if `query` missing, 409 if caller not provisioned
- Response
```
{
  "items": [
    { "id": 12, "name": "Engineering", "description": "Tech discussions", "member_count": 1250 }
  ],
  "next_cursor": "..."
}
```

GET /v1/hashtags/search?query=&limit=&cursor=
- Auth required; same-company scope; 422 if `query` missing, 409 if caller not provisioned
- Response
```
{
  "items": [
    { "name": "#shipping", "usage_count": 42 }
  ],
  "next_cursor": "..."
}
```

### Media

POST /v1/media/presign
- Auth required; returns presigned PUT URL for S3 (iOS uploads directly)
- Request
```
{ "contentType": "image/jpeg", "sizeBytes": 123456 }
```
- 200 OK
```
{
  "key": "media/original/<uuid>",
  "uploadUrl": "https://s3...",
  "headers": { "Content-Type": "image/jpeg" },
  "callbackSignature": "base64-hmac"   // present if configured
}
```

POST /v1/media/callback
- Auth required; record uploaded asset
- Request
```
{ "key": "media/original/<uuid>", "mimeType": "image/jpeg", "width": 640, "height": 480, "durationSeconds": 0 }
```
- 201 Created
```
{ "id": 77, "key": "media/original/<uuid>", "mime_type": "image/jpeg", "cdn_url": "https://cdn.example.com/media/original/<uuid>" }
```

Notes
- Allowlisted content types: images (jpeg/png/webp), video (mp4)
- Size limits are enforced; rejected with 400 if exceeded
- Client reads via CloudFront if configured, otherwise direct S3 path

### Verification

POST /v1/verification/start
- Auth required
- Request `{ "method": "email|video|thirdparty" }`
- 200 OK (pending)
```
{ "status": "pending", "method": "email", "dev_code": "123456" }
```

POST /v1/verification/finish
- Auth required
- Request (method‑specific fields)
```
// email
{ "method": "email", "code": "123456" }

// video
{ "method": "video", "mediaKey": "media/original/<uuid>" }

// third-party
{ "method": "thirdparty", "token": "provider-token" }
```
- 200 OK: `{ "verified": true }`

POST /users/verify-employment (alias: /v1/users/verify-employment)
- Auth required; delegates to verification start (method defaults to email)
- Request body: `{ "method": "email|video|thirdparty" }`
- 200 OK: same as `/v1/verification/start`

### Devices (APNs)

POST /v1/devices
- Auth required; idempotent by unique apns_token
- Request
```
{ "apnsToken": "<token>", "platform": "ios" }
```
- Responses
  - 201 Created on first create, 200 OK on replay
```
{ "id": 55, "apns_token": "<token>", "platform": "ios" }
```

### Moderation (MVP)

POST /v1/reports
- Auth required
- Request
```
{ "targetType": "post", "targetId": 101, "reason": "spam" }
```
- 201 Created: `{ "id": 42 }`

GET /v1/reports?status=open|resolved
- 200 OK
```
{ "items": [ { "id": 42, "target_type": "post", "target_id": 101, "reason": "spam", "status": "open", "created_at": "...", "updated_at": "..." } ] }
```

PUT /v1/reports/{id}/resolve
- 200 OK `{ "status": "resolved" }` (scoped to reporter/company)

### Messaging (Polling)

GET /v1/conversations?limit=&cursor=
- Auth required; returns DM conversations (same company)
- Response items: `{ "id": 1, "other_user_profile": { "id": 12, "handle": "erin", "display_name": "Erin", "profile_image_url": "..." }, "last_message": "...", "last_message_timestamp": "...", "unread_count": 0 }`

POST /v1/conversations
- Auth required; starts or returns an existing DM
- Request: `{ "participantUserId": <int> }`
- Response: conversation DTO as above

GET /v1/conversations/{id}/messages?limit=&cursor=
- Auth required; returns `{ "items": [message...], "next_cursor": "..." }`
- Message DTO: `{ "id": 1, "sender_id": 12, "content": "hi", "attachments": [], "created_at": "..." }`

POST /v1/conversations/{id}/messages
- Auth required
- Request: `{ "content": "<text>", "attachments": [] }`
- Response: message DTO

### Channels (if used)

GET /v1/channels?limit=&cursor=
- Auth required; returns `{ "items": [{ "id": 1, "name": "General", "member_count": 10, "is_public": true }], "next_cursor": "..." }`

GET /v1/channels/{id}/messages?limit=&cursor=
- Same shape as DM messages

POST /v1/channels/{id}/messages
- Request: `{ "content": "<text>", "attachments": [] }`
- Response: message DTO

### Notifications (Polling)

GET /v1/notifications?limit=&cursor=
- Auth required
- Response: `{ "items": [{ "id": 1, "type": "like", "created_at": "...", "unread": true, "payload": { ... } }], "next_cursor": "..." }`

POST /v1/notifications/{id}/read
- Auth required
- Response: `{ "read": true }`

## Database Schema (MVP)

Key tables (relevant columns shown). Full DDL: `apps/api/src/main/resources/db/migration/V1__baseline_mvp.sql`.

- companies
  - id (PK), name, domain (UNIQUE), created_at
- users
  - id (PK), firebase_uid (UNIQUE), handle (UNIQUE), company_id (FK), created_at
- verifications
  - user_id (PK/FK users.id), method, verified, verified_at
- media_assets
  - id (PK), owner_id (FK users.id), s3_key (UNIQUE), mime_type, width, height, duration_seconds, created_at
- posts
  - id (PK), author_id (FK), company_id (FK), content, media_asset_id (FK nullable), likes_count, created_at
  - index (company_id, created_at DESC)
- likes
  - id (PK), user_id (FK), post_id (FK), created_at, UNIQUE(user_id, post_id)
- reports
  - id (PK), target_type, target_id, reporter_id (FK), reason, status, created_at, updated_at
- devices
  - id (PK), user_id (FK), apns_token (UNIQUE), platform, created_at

## Guardrails & Notes

- Auth: verify Firebase JWT on every request; refused if missing/invalid
- Privacy: no PII in logs; tokens never logged
- Idempotency: `POST /v1/posts` requires `Idempotency-Key`; devices idempotent by `apns_token`
- Rate limits: applied per IP/user via Redis; treat 429 defensively
- Media: upload directly to S3 using presigned URL; do not proxy through the API
- Pagination: always treat `cursor` as opaque; pass `limit` (1..100)

## Quick cURL Examples

Identity
```
curl -H "Authorization: Bearer $TOKEN" https://api.<your-domain>/v1/me
```
Create post (idempotent)
```
IDEM=$(uuidgen)
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Idempotency-Key: $IDEM" \
  -d '{"content":"hello world"}' https://api.<your-domain>/v1/posts
```
Presign + upload image
```
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"contentType":"image/jpeg","sizeBytes":12345}' https://api.<your-domain>/v1/media/presign
# PUT to uploadUrl with header Content-Type: image/jpeg
```

---

For architecture and scaling context, see `docs/ARCHITECTURE.md` and `AGENTS.md`.
GET /v1/posts/liked?limit=&cursor=
- Auth required; caller’s liked posts scoped to their company
- Same post shape as `/v1/feed` with `next_cursor`

GET /v1/posts/saved?limit=&cursor=
- Auth required; caller’s saved posts in their company
- Same response shape; cursor is based on save timestamp

POST /v1/posts/{id}/save
- Auth required; idempotent
- 201 on first save, 200 if already saved
```
{ "post_id": 101, "saved": true }
```

DELETE /v1/posts/{id}/save
- Removes bookmark; `{ "post_id": 101, "saved": false }`
- 404 if post doesn’t exist, 403 if cross-company
