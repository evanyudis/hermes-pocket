# Hermes Web UI API Contract for iOS MVP

Source analyzed: `nesquena/hermes-webui`

Usage assumption:
- Hermes Pocket connects to an existing deployed Hermes Web UI instance
- no backend fork or backend code change required for MVP

## Scope

This contract covers only what native iOS MVP needs:

- password auth
- cookie session persistence
- multi-session list/load/create
- send message
- receive streamed reply via SSE
- cancel/check stream state

## Important backend behavior

### 1. Auth model

Hermes Web UI uses cookie auth, not bearer token auth.

- login sets `hermes_session` cookie
- cookie is `HttpOnly`
- session is server-side
- default session TTL resolves from backend config/env

Relevant routes:
- `POST /api/auth/login`
- `GET /api/auth/status`
- `POST /api/auth/logout`

### 2. CSRF behavior

Browser clients use `X-Hermes-CSRF-Token`.

Native app can avoid CSRF path if it does **not** send `Origin` or `Referer` headers. Backend only enforces CSRF for browser-style unsafe requests that include `Origin` or `Referer`.

Implication for iOS:
- use cookie-backed `URLSession`
- do not manually add `Origin`/`Referer`
- no CSRF bootstrap endpoint needed for MVP

### 3. Streaming model

Chat is:
1. `POST /api/chat/start`
2. receive `stream_id`
3. open `GET /api/chat/stream?stream_id=...`
4. consume SSE events until `done` + `stream_end`

### 4. Session model

WebUI is multi-session already.

Core routes:
- `GET /api/sessions`
- `POST /api/session/new`
- `GET /api/session?session_id=...`

---

## Endpoint contract

## `GET /api/auth/status`

Purpose:
- discover whether auth is enabled
- know whether current cookie session is valid

Response shape:

```json
{
  "auth_enabled": true,
  "logged_in": false,
  "password_auth_enabled": true,
  "passwordless_enabled": false,
  "passkeys_enabled": false,
  "passkeys_count": 0,
  "passkey_feature_flag": false
}
```

MVP use:
- if `auth_enabled == false`, skip login UI
- if `logged_in == true`, go straight into app

## `POST /api/auth/login`

Request:

```json
{
  "password": "..."
}
```

Success:
- HTTP 200
- sets auth cookie

Response:

```json
{
  "ok": true
}
```

Failure:
- `401 Invalid password`
- `429 Too many attempts. Try again in a minute.`

## `POST /api/auth/logout`

Response:

```json
{
  "ok": true
}
```

Effect:
- invalidates server session
- clears cookie

## `GET /api/sessions`

Purpose:
- load sidebar/session list

Response shape:

```json
{
  "sessions": [
    {
      "session_id": "abc123",
      "title": "Untitled",
      "message_count": 4,
      "updated_at": 1712345678.0,
      "last_message_at": 1712345678.0,
      "model": "...",
      "profile": "default",
      "active_stream_id": null
    }
  ],
  "cli_count": 0,
  "all_profiles": false,
  "active_profile": "default",
  "other_profile_count": 0,
  "server_time": 1712345678.0,
  "server_tz": "+0700"
}
```

MVP fields to consume:
- `session_id`
- `title`
- `message_count`
- `updated_at`
- `last_message_at`
- `model`
- `active_stream_id`

Ignore rest for MVP.

## `POST /api/session/new`

Request:

```json
{
  "workspace": null,
  "model": null,
  "model_provider": null,
  "profile": "default"
}
```

Success response:

```json
{
  "session": {
    "session_id": "newid",
    "title": "Untitled",
    "messages": []
  }
}
```

MVP use:
- create conversation before first send
- or lazily create on first compose

## `GET /api/session?session_id=...`

Important query params:
- `session_id` required
- `messages=1` default
- `messages=0` metadata only
- `msg_limit=N` optional
- `msg_before=N` optional paging
- `resolve_model=0|1` optional

Response shape:

```json
{
  "session": {
    "session_id": "abc123",
    "title": "Chat",
    "messages": [
      {"role": "user", "content": "Hi"},
      {"role": "assistant", "content": "Hello"}
    ],
    "message_count": 2,
    "tool_calls": [],
    "active_stream_id": null,
    "pending_user_message": null,
    "pending_attachments": [],
    "pending_started_at": null,
    "context_length": 200000,
    "threshold_tokens": 0,
    "last_prompt_tokens": 0
  }
}
```

MVP fields:
- `session_id`
- `title`
- `messages[]`
- `message_count`
- `active_stream_id`
- `pending_user_message`
- `pending_started_at`

Message minimum contract:

```json
{
  "role": "user|assistant|tool",
  "content": "string or structured payload",
  "timestamp": 1712345678.0
}
```

For MVP, support string `content` first.

## `POST /api/chat/start`

Purpose:
- submit user message
- start async streamed turn

Request:

```json
{
  "session_id": "abc123",
  "message": "Hello",
  "workspace": null,
  "model": null,
  "model_provider": null,
  "attachments": [],
  "profile": "default"
}
```

Success response:

```json
{
  "stream_id": "run123",
  "session_id": "abc123",
  "pending_started_at": 1712345678.0,
  "turn_id": "optional",
  "title": "Untitled"
}
```

Possible conflict:

```json
{
  "error": "session already has an active stream",
  "active_stream_id": "existing",
  "_status": 409
}
```

MVP behavior:
- optimistic append local user message
- connect SSE with `stream_id`
- if 409, reload session and reattach to existing stream

## `GET /api/chat/stream?stream_id=...`

Purpose:
- receive streaming turn over Server-Sent Events

Content-Type:
- `text/event-stream`

MVP SSE events to support:

### `token`
Append assistant text chunk.

Example data:

```json
{"text":"Hello"}
```

### `reasoning`
Optional hidden/secondary thinking text.

Example:

```json
{"text":"..."}
```

MVP can ignore or store separately.

### `tool`
Tool started.

Example:

```json
{
  "name": "bash",
  "preview": "Running command",
  "args": {}
}
```

MVP can ignore or show compact activity row.

### `tool_complete`
Tool finished.

Example:

```json
{
  "name": "bash",
  "preview": "Done",
  "args": {},
  "is_error": false
}
```

### `approval`
Agent asks for approval.

Not required for first MVP if scope is chat-only, but app should surface as unsupported state instead of silently hanging.

### `clarify`
Agent asks question before continuing.

Same handling as approval.

### `title`
Session title updated.

Example:

```json
{"session_id":"abc123","title":"Tunnel setup"}
```

### `context_status`
Context/prefill status.

Safe to ignore in MVP.

### `done`
Final authoritative session payload.

Example shape:

```json
{
  "session": {
    "session_id": "abc123",
    "title": "Tunnel setup",
    "messages": [...],
    "message_count": 2,
    "tool_calls": []
  },
  "usage": {
    "input_tokens": 100,
    "output_tokens": 50,
    "estimated_cost": 0.001
  }
}
```

Client rule:
- replace optimistic local state with `done.session`

### `apperror`
Application-level failure.

Example:

```json
{
  "label": "Gateway request failed",
  "type": "gateway_error",
  "message": "...",
  "hint": "..."
}
```

### `cancel`
Turn cancelled.

### `stream_end`
Transport-level end marker.

Client rule:
- close SSE on `stream_end`, `cancel`, or terminal error

## `GET /api/chat/stream/status?stream_id=...`

Response:

```json
{
  "active": true,
  "stream_id": "run123",
  "replay_available": false
}
```

MVP use:
- recover after app foreground/reconnect
- decide whether to reattach or hard refresh session

## `GET /api/chat/cancel?stream_id=...`

Response:

```json
{
  "ok": true,
  "cancelled": true,
  "stream_id": "run123"
}
```

MVP use:
- stop button

---

## Recommended iOS client contract

## Auth/session persistence

Use:
- `URLSessionConfiguration.default`
- shared `HTTPCookieStorage` or app-owned `HTTPCookieStorage`
- Keychain for base URL/password if user wants saved connection

Do not use bearer token architecture.

## Native transport rules

- preserve cookies across requests
- no `Origin` header
- no `Referer` header
- accept SSE over normal HTTPS tunnel endpoint

## Suggested local models

### RemoteConnection
- baseURL
- passwordSaved
- tunnelLabel

### AuthState
- authEnabled
- loggedIn
- cookiePresent

### ChatSessionSummary
- sessionID
- title
- messageCount
- updatedAt
- model
- activeStreamID

### ChatSessionDetail
- summary fields
- messages
- pendingUserMessage
- pendingStartedAt

### ChatMessage
- id local
- role
- content
- timestamp
- status: sent | streaming | failed

### StreamEvent
- token
- reasoning
- toolStart
- toolComplete
- title
- done
- appError
- cancel
- streamEnd

---

## MVP gaps / known risks

1. API is not versioned.
2. SSE is required; no websocket API.
3. Approval/clarify flows exist and can interrupt a turn.
4. Message `content` can be richer than plain string in some cases.
5. Backend also has profile/workspace/model concepts; MVP can keep these mostly fixed.
6. No dedicated native auth token endpoint exists today.

---

## Recommended MVP subset

Implement first:
- `GET /api/auth/status`
- `POST /api/auth/login`
- `GET /api/sessions`
- `POST /api/session/new`
- `GET /api/session`
- `POST /api/chat/start`
- `GET /api/chat/stream`
- `GET /api/chat/stream/status`
- `GET /api/chat/cancel`
- `POST /api/auth/logout`

Everything else later.
