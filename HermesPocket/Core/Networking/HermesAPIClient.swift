import Foundation

protocol HermesAPIClientProtocol: Sendable {
    func authStatus() async throws -> AuthStatusDTO
    func login(password: String) async throws
    func logout() async throws
    func fetchSessions() async throws -> SessionsListDTO
    func createSession(request: CreateSessionRequestDTO) async throws -> SessionEnvelopeDTO
    func renameSession(request: SessionRenameRequestDTO) async throws -> SessionMutationResponseDTO
    func archiveSession(request: SessionActionRequestDTO) async throws -> SessionMutationResponseDTO
    func deleteSession(request: SessionActionRequestDTO) async throws -> SessionDeleteResponseDTO
    func fetchSession(sessionID: String, includeMessages: Bool, limit: Int?) async throws -> SessionEnvelopeDTO
    func startChat(request: ChatStartRequestDTO) async throws -> ChatStartResponseDTO
    func streamChat(streamID: String) -> AsyncThrowingStream<HermesStreamEvent, Error>
    func streamStatus(streamID: String) async throws -> StreamStatusDTO
    func cancelStream(streamID: String) async throws -> CancelStreamDTO
    func fetchPendingApproval(sessionID: String) async throws -> ApprovalPendingEnvelopeDTO
    func respondApproval(request: ApprovalRespondRequestDTO) async throws -> ApprovalRespondResponseDTO
    func fetchPendingClarify(sessionID: String) async throws -> ClarifyPendingEnvelopeDTO
    func fetchModels() async throws -> ModelsListDTO
    func respondClarify(request: ClarifyRespondRequestDTO) async throws -> ClarifyRespondResponseDTO
}

final class HermesAPIClient: HermesAPIClientProtocol, @unchecked Sendable {
    private let requestFactory: HermesRequestFactory
    private let session: HermesHTTPSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: HermesHTTPSession = HermesHTTPSession()) {
        self.requestFactory = HermesRequestFactory(baseURL: baseURL)
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func authStatus() async throws -> AuthStatusDTO {
        let request = try requestFactory.makeJSONRequest(path: "/api/auth/status", method: "GET")
        return try await perform(request, as: AuthStatusDTO.self)
    }

    func login(password: String) async throws {
        let payload = try encoder.encode(LoginRequest(password: password))
        let request = try requestFactory.makeJSONRequest(path: "/api/auth/login", method: "POST", body: payload)
        let _: LoginResponse = try await perform(request, as: LoginResponse.self)
    }

    func logout() async throws {
        let request = try requestFactory.makeJSONRequest(path: "/api/auth/logout", method: "POST", body: Data("{}".utf8))
        let _: LogoutResponse = try await perform(request, as: LogoutResponse.self)
    }

    func fetchSessions() async throws -> SessionsListDTO {
        let request = try requestFactory.makeJSONRequest(path: "/api/sessions", method: "GET")
        return try await perform(request, as: SessionsListDTO.self)
    }

    func createSession(request: CreateSessionRequestDTO) async throws -> SessionEnvelopeDTO {
        let body = try encoder.encode(request)
        let urlRequest = try requestFactory.makeJSONRequest(path: "/api/session/new", method: "POST", body: body)
        return try await perform(urlRequest, as: SessionEnvelopeDTO.self)
    }

    func renameSession(request: SessionRenameRequestDTO) async throws -> SessionMutationResponseDTO {
        let body = try encoder.encode(request)
        let urlRequest = try requestFactory.makeJSONRequest(path: "/api/session/rename", method: "POST", body: body)
        return try await perform(urlRequest, as: SessionMutationResponseDTO.self)
    }

    func archiveSession(request: SessionActionRequestDTO) async throws -> SessionMutationResponseDTO {
        let body = try encoder.encode(request)
        let urlRequest = try requestFactory.makeJSONRequest(path: "/api/session/archive", method: "POST", body: body)
        return try await perform(urlRequest, as: SessionMutationResponseDTO.self)
    }

    func deleteSession(request: SessionActionRequestDTO) async throws -> SessionDeleteResponseDTO {
        let body = try encoder.encode(request)
        let urlRequest = try requestFactory.makeJSONRequest(path: "/api/session/delete", method: "POST", body: body)
        return try await perform(urlRequest, as: SessionDeleteResponseDTO.self)
    }

    func fetchSession(sessionID: String, includeMessages: Bool = true, limit: Int? = nil) async throws -> SessionEnvelopeDTO {
        guard var components = URLComponents(url: try requestFactory.makeJSONRequest(path: "/api/session", method: "GET").url!, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidURL
        }
        var items = [
            URLQueryItem(name: "session_id", value: sessionID),
            URLQueryItem(name: "messages", value: includeMessages ? "1" : "0")
        ]
        if let limit {
            items.append(URLQueryItem(name: "msg_limit", value: String(limit)))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw HermesError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, as: SessionEnvelopeDTO.self)
    }

    func startChat(request: ChatStartRequestDTO) async throws -> ChatStartResponseDTO {
        let body = try encoder.encode(request)
        let urlRequest = try requestFactory.makeJSONRequest(path: "/api/chat/start", method: "POST", body: body)
        return try await perform(urlRequest, as: ChatStartResponseDTO.self)
    }

    func streamChat(streamID: String) -> AsyncThrowingStream<HermesStreamEvent, Error> {
        let request: URLRequest
        do {
            request = try requestFactory.makeSSERequest(
                path: "/api/chat/stream",
                queryItems: [URLQueryItem(name: "stream_id", value: streamID)]
            )
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }

        let streamSession = session.stream

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let sseClient = HermesSSEClient(session: streamSession)
                    for try await frame in sseClient.events(for: request) {
                        continuation.yield(HermesStreamEvent(frame: frame))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func streamStatus(streamID: String) async throws -> StreamStatusDTO {
        guard var components = URLComponents(url: try requestFactory.makeJSONRequest(path: "/api/chat/stream/status", method: "GET").url!, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "stream_id", value: streamID)]
        guard let url = components.url else {
            throw HermesError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, as: StreamStatusDTO.self)
    }

    func cancelStream(streamID: String) async throws -> CancelStreamDTO {
        guard var components = URLComponents(url: try requestFactory.makeJSONRequest(path: "/api/chat/cancel", method: "GET").url!, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "stream_id", value: streamID)]
        guard let url = components.url else {
            throw HermesError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, as: CancelStreamDTO.self)
    }

    func fetchPendingApproval(sessionID: String) async throws -> ApprovalPendingEnvelopeDTO {
        guard var components = URLComponents(url: try requestFactory.makeJSONRequest(path: "/api/approval/pending", method: "GET").url!, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "session_id", value: sessionID)]
        guard let url = components.url else {
            throw HermesError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, as: ApprovalPendingEnvelopeDTO.self)
    }

    func respondApproval(request: ApprovalRespondRequestDTO) async throws -> ApprovalRespondResponseDTO {
        let body = try encoder.encode(request)
        let urlRequest = try requestFactory.makeJSONRequest(path: "/api/approval/respond", method: "POST", body: body)
        return try await perform(urlRequest, as: ApprovalRespondResponseDTO.self)
    }

    func fetchPendingClarify(sessionID: String) async throws -> ClarifyPendingEnvelopeDTO {
        guard var components = URLComponents(url: try requestFactory.makeJSONRequest(path: "/api/clarify/pending", method: "GET").url!, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "session_id", value: sessionID)]
        guard let url = components.url else {
            throw HermesError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, as: ClarifyPendingEnvelopeDTO.self)
    }

    func fetchModels() async throws -> ModelsListDTO {
        let request = try requestFactory.makeJSONRequest(path: "/api/models", method: "GET")
        return try await perform(request, as: ModelsListDTO.self)
    }

    func respondClarify(request: ClarifyRespondRequestDTO) async throws -> ClarifyRespondResponseDTO {
        let body = try encoder.encode(request)
        let urlRequest = try requestFactory.makeJSONRequest(path: "/api/clarify/respond", method: "POST", body: body)
        return try await perform(urlRequest, as: ClarifyRespondResponseDTO.self)
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.rest.data(for: request)
            try validate(response: response, data: data)
            do {
                return try decoder.decode(T.self, from: data)
            } catch let DecodingError.keyNotFound(key, context) {
                let path = (context.codingPath.map(\.stringValue) + [key.stringValue]).joined(separator: ".")
                let bodySnippet = String(data: data.prefix(4000), encoding: .utf8) ?? "<non-utf8 body>"
                throw HermesError.decoding("keyNotFound: \(path) | body(\(data.count)B): \(bodySnippet)")
            } catch let DecodingError.typeMismatch(type, context) {
                let path = context.codingPath.map(\.stringValue).joined(separator: ".")
                let bodySnippet = String(data: data.prefix(4000), encoding: .utf8) ?? "<non-utf8 body>"
                throw HermesError.decoding("typeMismatch(\(type)) at: \(path) | body(\(data.count)B): \(bodySnippet)")
            } catch let DecodingError.valueNotFound(type, context) {
                let path = context.codingPath.map(\.stringValue).joined(separator: ".")
                let bodySnippet = String(data: data.prefix(4000), encoding: .utf8) ?? "<non-utf8 body>"
                throw HermesError.decoding("valueNotFound(\(type)) at: \(path) | body(\(data.count)B): \(bodySnippet)")
            } catch {
                let bodySnippet = String(data: data.prefix(4000), encoding: .utf8) ?? "<non-utf8 body>"
                throw HermesError.decoding("\(error.localizedDescription) | body(\(data.count)B): \(bodySnippet)")
            }
        } catch let error as HermesError {
            throw error
        } catch {
            throw HermesError.transport(error.localizedDescription)
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw HermesError.transport("Non-HTTP response")
        }

        switch http.statusCode {
        case 200 ... 299:
            return
        case 401:
            throw HermesError.unauthorized
        case 403:
            throw HermesError.forbidden
        case 404:
            throw HermesError.backend(message: "HTTP 404 for \(http.url?.absoluteString ?? "request") — body: \(String(data: data.prefix(400), encoding: .utf8) ?? "")")
        case 422:
            throw HermesError.backend(message: "HTTP 422 for \(http.url?.absoluteString ?? "request") — body: \(String(data: data.prefix(800), encoding: .utf8) ?? "")")
        case 409:
            let conflict = try? decoder.decode(ChatStartResponseDTO.self, from: data)
            throw HermesError.conflictActiveStream(activeStreamID: conflict?.activeStreamId)
        case 429:
            throw HermesError.rateLimited
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw HermesError.backend(message: message)
        }
    }
}

private struct LoginRequest: Encodable {
    let password: String
}

private struct LoginResponse: Decodable {
    let ok: Bool
}

private struct LogoutResponse: Decodable {
    let ok: Bool
}
