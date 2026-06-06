# Hermes Pocket Implementation Plan

## Product target

Native iOS Swift app for remote Hermes Web UI.

Connection model:
- user enters tunnel URL
- app logs in with password
- app stores cookie session
- app chats against existing deployed Hermes Web UI backend

Backend strategy:
- no fork required for MVP
- no backend modification assumed
- app consumes existing Hermes Web UI API contract directly

MVP target:
- stable multi-session conversation UX
- full Swift stack
- no webview shell

---

## Recommended stack

- SwiftUI
- Observation
- URLSession
- AsyncSequence / URLSession bytes for SSE parsing
- Keychain for credentials
- HTTPCookieStorage for auth cookie
- SwiftData or lightweight local cache for session snapshots

Recommendation:
- start with in-memory + disk JSON cache
- add SwiftData only if offline caching needs become bigger

---

## Architecture

## 1. App layers

### Presentation
- `AppRootView`
- `ConnectionSetupView`
- `LoginView`
- `SessionListView`
- `ChatView`
- `ComposerView`
- `SettingsView`

### State
- `AppState`
- `AuthStore`
- `SessionStore`
- `ChatStore`
- `ConnectionStore`

### Networking
- `HermesAPIClient`
- `HermesAuthClient`
- `HermesSessionClient`
- `HermesChatClient`
- `SSEStreamParser`

### Persistence
- `CredentialStore` (Keychain)
- `CookieStoreAdapter`
- `SessionCache`

---

## 2. Core flows

## Flow A: first connection
1. User enters tunnel URL
2. App calls `GET /api/auth/status`
3. If auth enabled and not logged in, show password screen
4. `POST /api/auth/login`
5. Persist cookie automatically
6. Load sessions

## Flow B: open session
1. Load `GET /api/sessions`
2. User taps session
3. Load `GET /api/session?session_id=...`
4. Render transcript
5. If `active_stream_id != null`, optionally reattach stream

## Flow C: create new chat
1. `POST /api/session/new`
2. Add returned session to list
3. Open empty chat screen

## Flow D: send message
1. optimistic append user message
2. `POST /api/chat/start`
3. store `stream_id`
4. open SSE `GET /api/chat/stream?stream_id=...`
5. append `token` chunks to live assistant message
6. on `done`, replace local session with authoritative payload
7. on `stream_end`, close stream

## Flow E: reconnect
1. app foreground/network restore
2. if current session has `active_stream_id`, call `GET /api/chat/stream/status`
3. if active, reattach SSE
4. else refresh `GET /api/session`

---

## 3. Data model draft

```swift
struct HermesSessionSummary: Identifiable, Codable {
    let id: String
    var title: String
    var messageCount: Int
    var updatedAt: Date?
    var lastMessageAt: Date?
    var model: String?
    var activeStreamID: String?
}

struct HermesMessage: Identifiable, Codable {
    let id: UUID
    var role: String
    var content: String
    var timestamp: Date?
    var isStreaming: Bool
}
```

Need adapter layer because backend `content` may become non-string later.

---

## 4. Networking plan

## HermesAPIClient
Responsibilities:
- base URL normalization
- cookie-aware requests
- JSON decoding
- error mapping

## SSEStreamParser
Responsibilities:
- parse `event:` + `data:` frames
- emit typed Swift enum events
- support multiline `data:`
- stop on cancellation

Draft enum:

```swift
enum HermesStreamEvent {
    case token(String)
    case reasoning(String)
    case toolStart(name: String, preview: String?)
    case toolComplete(name: String, preview: String?, isError: Bool)
    case title(String)
    case done(HermesDonePayload)
    case appError(message: String, hint: String?)
    case cancel
    case streamEnd
    case unknown(name: String, rawJSON: String)
}
```

---

## 5. MVP screens

## Screen 1: connection
- tunnel URL field
- connect button
- recent connections optional

## Screen 2: login
- password field
- login button
- error state

## Screen 3: sessions
- list existing sessions
- new chat button
- pull to refresh
- running session indicator

## Screen 4: chat
- transcript
- composer
- send button
- stop button while streaming
- basic activity row for tool events optional

## Screen 5: settings
- server URL
- logout
- clear saved credentials

---

## 6. Milestones

## Phase 0 — scaffold
- create Xcode project
- set bundle/app targets
- wire SwiftUI navigation shell
- add networking module

## Phase 1 — connection/auth
- connection form
- auth status check
- password login
- cookie persistence
- logout

## Phase 2 — sessions
- list sessions
- create session
- open session
- refresh session

## Phase 3 — streaming chat
- send message
- SSE parser
- live token rendering
- done reconciliation
- cancel flow
- reconnect flow

## Phase 4 — polish MVP
- loading/error states
- empty states
- retry logic
- basic local cache
- tunnel URL validation

## Phase 5 — post-MVP
- rename/delete/archive sessions
- approval/clarify UX
- markdown rendering
- attachments
- multiple saved servers
- biometric unlock for saved password
- iPad/macOS support

---

## 7. Technical decisions

## Decision A: native, not webview
Reason:
- full Swift stack requirement
- better app feel
- better state recovery
- easier future offline caching

## Decision B: cookie auth, not token auth abstraction
Reason:
- matches backend reality
- avoids fake abstraction
- simpler MVP

## Decision C: SSE over URLSession bytes
Reason:
- backend already ships SSE
- no websocket translation layer needed

## Decision D: optimistic send + authoritative done replace
Reason:
- best UX
- matches backend stream contract
- simpler conflict recovery

---

## 8. Open questions

1. Should app support multiple saved Hermes backends in MVP?
2. Should password be saved, or cookie only?
3. Should we render markdown in MVP or plain text first?
4. How should approval/clarify interruptions appear in native UX?
5. Do you want iPhone-only first, or universal layout from day one?

---

## 9. Immediate next implementation step

Recommended next step:
- scaffold SwiftUI app structure + networking core first

Suggested first folders:
- `HermesPocket/App`
- `HermesPocket/Core/Networking`
- `HermesPocket/Core/Models`
- `HermesPocket/Core/Persistence`
- `HermesPocket/Features/Auth`
- `HermesPocket/Features/Sessions`
- `HermesPocket/Features/Chat`
