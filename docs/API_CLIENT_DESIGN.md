# Hermes Pocket API Client Design

## Goal

Build native Swift client layer for Hermes Pocket.

This layer talks directly to Hermes Web UI backend over HTTPS tunnel using:
- cookie auth
- JSON REST
- SSE streaming

## Design principles

- native-first
- small surface
- backend-faithful contract
- testable transport
- reconnect-safe
- session-centric state

---

## Module layout

```text
HermesPocket/
  Core/
    Networking/
      HermesAPIClient.swift
      HermesRequestFactory.swift
      HermesSession.swift
      HermesError.swift
      SSE/
        HermesSSEClient.swift
        HermesSSEParser.swift
        HermesStreamEvent.swift
    Models/
      Auth/
      Sessions/
      Chat/
```

---

## Layer split

## 1. HermesAPIClient

Top-level facade.

Responsibilities:
- expose async methods app uses
- call request factory
- decode JSON
- map transport/backend errors
- keep one cookie-aware `URLSession`

Draft:

```swift
protocol HermesAPIClientProtocol {
    func authStatus() async throws -> AuthStatusDTO
    func login(password: String) async throws
    func logout() async throws

    func fetchSessions() async throws -> SessionsListDTO
    func createSession(request: CreateSessionRequestDTO) async throws -> SessionEnvelopeDTO
    func fetchSession(sessionID: String, includeMessages: Bool, limit: Int?) async throws -> SessionEnvelopeDTO

    func startChat(request: ChatStartRequestDTO) async throws -> ChatStartResponseDTO
    func streamChat(streamID: String) -> AsyncThrowingStream<HermesStreamEvent, Error>
    func streamStatus(streamID: String) async throws -> StreamStatusDTO
    func cancelStream(streamID: String) async throws -> CancelStreamDTO
}
```

---

## 2. HermesRequestFactory

Responsibilities:
- normalize paths
- encode JSON bodies
- attach headers
- avoid browser-only headers

Rules:
- send `Content-Type: application/json` for JSON POSTs
- send `Accept: application/json` for REST
- send `Accept: text/event-stream` for SSE
- do not manually send `Origin`
- do not manually send `Referer`

Draft:

```swift
struct HermesRequestFactory {
    let baseURL: URL

    func makeJSONRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest
    func makeSSERequest(path: String, queryItems: [URLQueryItem]) throws -> URLRequest
}
```

---

## 3. HermesSession

Wrapper for configured `URLSession`.

Responsibilities:
- cookie persistence
- timeout config
- connectivity behavior
- optional custom cookie store

Recommendation:
- use dedicated `URLSessionConfiguration.default`
- use shared or custom `HTTPCookieStorage`
- use `waitsForConnectivity = true`
- use longer timeout for SSE requests

Draft:

```swift
final class HermesHTTPSession {
    let rest: URLSession
    let stream: URLSession
}
```

Reason for split:
- REST and SSE have different timeout needs
- easier cancellation isolation

---

## 4. HermesSSEClient

Responsibilities:
- open byte stream
- parse SSE frames
- convert to typed events
- stop on cancellation
- surface malformed frames safely

Implementation approach:
- `URLSession.bytes(for:)`
- parse lines incrementally
- support:
  - `event: token`
  - `data: {...}`
  - blank line = dispatch event

Draft:

```swift
protocol HermesSSEClientProtocol {
    func events(for request: URLRequest) -> AsyncThrowingStream<HermesSSEFrame, Error>
}
```

---

## 5. HermesSSEParser

Input:
- async byte or line stream

Output:
- `HermesSSEFrame`

Draft:

```swift
struct HermesSSEFrame {
    let event: String
    let data: String
    let id: String?
}
```

Rules:
- join multiple `data:` lines with `\n`
- keep last `event:` before dispatch
- reset frame on blank line
- ignore comments beginning with `:`

---

## 6. HermesStreamEvent mapping

Typed app-facing enum.

```swift
enum HermesStreamEvent: Equatable {
    case token(String)
    case reasoning(String)
    case toolStart(ToolEventDTO)
    case toolComplete(ToolEventDTO)
    case approval(ApprovalEventDTO)
    case clarify(ClarifyEventDTO)
    case title(TitleEventDTO)
    case contextStatus(ContextStatusDTO)
    case done(DoneEventDTO)
    case appError(AppErrorEventDTO)
    case cancel
    case streamEnd
    case unknown(name: String, payload: String)
}
```

MVP handling:
- render: `token`, `done`, `streamEnd`, `apperror`, `title`
- store but maybe hide: `reasoning`, `tool*`
- blocked state UI later: `approval`, `clarify`

---

## DTO set

## Auth

```swift
struct AuthStatusDTO: Decodable {
    let authEnabled: Bool
    let loggedIn: Bool
    let passwordAuthEnabled: Bool
    let passwordlessEnabled: Bool
    let passkeysEnabled: Bool
}
```

## Sessions

```swift
struct SessionsListDTO: Decodable {
    let sessions: [SessionSummaryDTO]
}

struct SessionSummaryDTO: Decodable, Identifiable {
    let sessionID: String
    let title: String
    let messageCount: Int
    let updatedAt: Double?
    let lastMessageAt: Double?
    let model: String?
    let activeStreamID: String?

    var id: String { sessionID }
}
```

## Session detail

```swift
struct SessionEnvelopeDTO: Decodable {
    let session: SessionDTO
}

struct SessionDTO: Decodable {
    let sessionID: String
    let title: String
    let messages: [MessageDTO]
    let messageCount: Int
    let activeStreamID: String?
    let pendingUserMessage: String?
    let pendingStartedAt: Double?
}

struct MessageDTO: Decodable {
    let role: String
    let content: MessageContentDTO
    let timestamp: Double?
}
```

Need custom decode for content.

## Message content strategy

Backend may return string or richer payload.

Use:

```swift
enum MessageContentDTO: Decodable, Equatable {
    case text(String)
    case unsupported
}
```

MVP:
- decode string as `.text`
- everything else `.unsupported`

Later:
- support arrays / structured content

## Chat start

```swift
struct ChatStartRequestDTO: Encodable {
    let sessionID: String
    let message: String
    let workspace: String?
    let model: String?
    let modelProvider: String?
    let attachments: [AttachmentDTO]
    let profile: String?
}

struct ChatStartResponseDTO: Decodable {
    let streamID: String
    let sessionID: String
    let pendingStartedAt: Double?
    let turnID: String?
    let title: String?
    let error: String?
    let activeStreamID: String?
}
```

## Done payload

```swift
struct DoneEventDTO: Decodable {
    let session: SessionDTO
    let usage: UsageDTO?
}
```

---

## Error model

```swift
enum HermesError: Error, Equatable {
    case invalidURL
    case unauthorized
    case forbidden
    case rateLimited
    case notFound
    case conflictActiveStream(activeStreamID: String?)
    case backend(message: String)
    case decoding(String)
    case transport(String)
    case streamEnded
}
```

Mapping rules:
- 401 -> `.unauthorized`
- 403 -> `.forbidden`
- 404 -> `.notFound`
- 409 + active stream payload -> `.conflictActiveStream`
- 429 -> `.rateLimited`

---

## App-facing repositories

Keep API client low-level.

Then add higher-level stores/repositories:

## AuthRepository
- check auth
- login
- logout
- determine launch route

## SessionRepository
- fetch summaries
- create session
- fetch session detail
- cache active session

## ChatRepository
- send message
- stream reply
- recover active stream
- cancel stream

This prevents SwiftUI views from handling raw DTO quirks.

---

## Stream recovery strategy

When chat screen appears:
1. load session detail
2. if `active_stream_id` exists:
   - call `streamStatus`
   - if active: reattach SSE
   - else: refresh session detail

When `startChat` returns conflict:
1. inspect `activeStreamID`
2. reattach to that stream
3. reload session on completion

---

## Testing plan

## Unit test
- request factory path building
- auth/session/chat JSON decoding
- content polymorphic decode
- SSE parser frame assembly
- stream event mapping
- error mapping

## Integration-style mock tests
- login sets cookie and next request reuses it
- token chunks assemble into assistant message
- done replaces optimistic message state
- reconnect reattaches existing stream

Use custom `URLProtocol` test double.

---

## Initial implementation order

1. `HermesError`
2. DTOs
3. `HermesRequestFactory`
4. `HermesHTTPSession`
5. `HermesAPIClient` REST methods
6. `HermesSSEParser`
7. `HermesSSEClient`
8. `streamChat()` mapping
9. repository/store integration

---

## Recommended first concrete code files

- `HermesPocket/Core/Networking/HermesError.swift`
- `HermesPocket/Core/Networking/HermesRequestFactory.swift`
- `HermesPocket/Core/Networking/HermesAPIClient.swift`
- `HermesPocket/Core/Networking/SSE/HermesSSEParser.swift`
- `HermesPocket/Core/Networking/SSE/HermesStreamEvent.swift`
- `HermesPocket/Core/Models/Auth/AuthStatusDTO.swift`
- `HermesPocket/Core/Models/Sessions/SessionDTO.swift`
- `HermesPocket/Core/Models/Chat/ChatStartDTO.swift`
