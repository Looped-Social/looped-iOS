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
- Auth required
- Returns identity from the token and provisioned user (if present)
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
    }
  }
}
```

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

