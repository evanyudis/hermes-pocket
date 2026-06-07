import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppState {
    enum Route {
        case connection
        case login
        case sessions
        case chat
        case settings
    }

    var route: Route = .connection
    var connection = ConnectionStore()
    var auth = AuthStore()
    var sessions = SessionStore()
    var chat = ChatStore()
    var currentSessionID: String?
    var isNewChatQueued = false
    var defaultModel = ""
    var defaultModelProvider = ""
    var availableModels: [ModelGroupDTO] = []
    var activeProvider: String?
    var serverDefaultModel: String?
    var isFetchingModels = false
    var isStreamDebugLoggingEnabled = false
    var completedToolSteps: [ToolCallStep] = []

    @ObservationIgnored let credentialStore = CredentialStore()
    @ObservationIgnored private var apiClient: HermesAPIClientProtocol?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var didReceiveDoneForActiveStream = false
    @ObservationIgnored private var didBootstrap = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.evanyudis.hermes-pocket", category: "ChatStream")

    init() {
        // Dev convenience: persist backend URL + session cookie so reinstalling
        // the app does not force re-entry during local development.
        let savedBaseURL = credentialStore.loadBaseURL()
        connection.baseURLString = savedBaseURL
        if connection.baseURL != nil {
            credentialStore.loadCookies().forEach { HTTPCookieStorage.shared.setCookie($0) }
        }
        defaultModel = credentialStore.loadDefaultModel()
        defaultModelProvider = credentialStore.loadDefaultModelProvider()
        isStreamDebugLoggingEnabled = credentialStore.loadStreamDebugLoggingEnabled()
        if !savedBaseURL.isEmpty {
            route = .chat
        }
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        guard !connection.trimmedBaseURLString.isEmpty else { return }
        await connect()
    }

    func connect() async {
        connection.lastError = nil
        auth.lastError = nil

        guard let baseURL = connection.baseURL else {
            connection.lastError = "Enter a valid http(s) backend URL."
            route = .connection
            return
        }

        connection.isLoading = true
        credentialStore.saveBaseURL(connection.trimmedBaseURLString)
        apiClient = HermesAPIClient(baseURL: baseURL)

        defer { connection.isLoading = false }

        do {
            let client = try requireAPIClient()
            let status = try await client.authStatus()
            auth.authEnabled = status.authEnabled
            auth.isLoggedIn = status.loggedIn || !status.authEnabled
            if let baseURL = connection.baseURL {
                credentialStore.saveCookies(HTTPCookieStorage.shared.cookies(for: baseURL) ?? [])
            }
            if auth.isLoggedIn {
                await fetchModels()
                await autoEnterChat()
            } else {
                route = .login
            }
        } catch {
            connection.lastError = readableError(error)
            route = .connection
        }
    }

    func login(password: String) async {
        auth.lastError = nil
        auth.isLoading = true
        defer { auth.isLoading = false }

        do {
            let client = try requireAPIClient()
            try await client.login(password: password)
            if let baseURL = connection.baseURL {
                credentialStore.saveCookies(HTTPCookieStorage.shared.cookies(for: baseURL) ?? [])
            }
            auth.isLoggedIn = true
            await fetchModels()
            await autoEnterChat()
        } catch {
            auth.lastError = readableError(error)
        }
    }

    func refreshSessions() async {
        sessions.lastError = nil
        sessions.isLoading = true
        defer { sessions.isLoading = false }

        do {
            let client = try requireAPIClient()
            let payload = try await client.fetchSessions()
            sessions.items = payload.sessions.sorted(by: sessionSort)
        } catch {
            sessions.lastError = readableError(error)
        }
    }

    func renameSession(sessionID: String, title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let client = try requireAPIClient()
            let payload = try await client.renameSession(request: SessionRenameRequestDTO(sessionID: sessionID, title: trimmed))
            if let session = payload.session {
                applySessionIfNeeded(session)
            } else if currentSessionID == sessionID {
                chat.sessionTitle = trimmed
            }
            await refreshSessions()
        } catch {
            sessions.lastError = readableError(error)
        }
    }

    func archiveSession(sessionID: String) async {
        do {
            let client = try requireAPIClient()
            let payload = try await client.archiveSession(request: SessionActionRequestDTO(sessionID: sessionID))
            if let session = payload.session, currentSessionID == sessionID {
                applySession(session)
            }
            await refreshSessions()
        } catch {
            sessions.lastError = readableError(error)
        }
    }

    func deleteSession(sessionID: String) async {
        do {
            let client = try requireAPIClient()
            _ = try await client.deleteSession(request: SessionActionRequestDTO(sessionID: sessionID))
            if currentSessionID == sessionID {
                startNewChatQueue()
            }
            await refreshSessions()
        } catch {
            sessions.lastError = readableError(error)
        }
    }

    func autoEnterChat() async {
        startNewChatQueue()
        await refreshSessions()
    }

    func createSession() async {
        sessions.lastError = nil
        sessions.isLoading = true
        defer { sessions.isLoading = false }

        do {
            let client = try requireAPIClient()
            let payload = try await client.createSession(
                request: CreateSessionRequestDTO(workspace: nil, model: defaultModel.isEmpty ? nil : defaultModel, modelProvider: defaultModelProvider.isEmpty ? nil : defaultModelProvider, profile: "default")
            )
            upsertSessionSummary(from: payload.session)
            await loadSession(sessionID: payload.session.sessionId)
        } catch {
            sessions.lastError = readableError(error)
        }
    }

    func startNewChatQueue() {
        isNewChatQueued = true
        stopLocalStream()
        resetPromptState()
        currentSessionID = nil
        chat = ChatStore()
        chat.sessionTitle = "New Chat"
        completedToolSteps = []
        route = .chat
    }

    func fetchModels() async {
        isFetchingModels = true
        defer { isFetchingModels = false }

        do {
            let client = try requireAPIClient()
            let payload = try await client.fetchModels()
            availableModels = payload.groups ?? []
            activeProvider = payload.activeProvider
            serverDefaultModel = payload.defaultModel
        } catch {
            // Silently fail — models are non-critical for core UX
        }
    }

    func loadSession(sessionID: String) async {
        isNewChatQueued = false
        stopLocalStream()
        resetPromptState()
        currentSessionID = sessionID
        route = .chat
        chat.lastError = nil
        chat.isLoading = true

        do {
            let client = try requireAPIClient()
            let payload = try await client.fetchSession(sessionID: sessionID, includeMessages: true, limit: nil)
            applySession(payload.session)
            chat.isLoading = false
            await refreshPendingPrompts(sessionID: payload.session.sessionId)
            if let activeStreamId = payload.session.activeStreamId {
                await reattachStreamIfNeeded(streamID: activeStreamId, sessionID: payload.session.sessionId)
            }
        } catch {
            chat.isLoading = false
            chat.lastError = readableError(error)
        }
    }

    func sendChat() async {
        let message = chat.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = chat.stagedAttachments
        guard !message.isEmpty || !attachments.isEmpty else { return }

        chat.lastError = nil
        resetPromptState()
        chat.pendingToolSteps = []
        completedToolSteps = []

        do {
            let client = try requireAPIClient()
            let sessionID = try await ensureSessionID()
            let now = Date().timeIntervalSince1970
            chat.messages.append(MessageDTO(role: "user", content: .text(message), timestamp: now, attachments: attachments))
            chat.messages.append(MessageDTO(role: "assistant", content: .text(""), timestamp: now))
            chat.isAwaitingAssistantStart = true
            chat.draft = ""
            chat.stagedAttachments = []

            do {
                let response = try await client.startChat(
                    request: ChatStartRequestDTO(
                        sessionId: sessionID,
                        message: message,
                        workspace: nil,
                        model: defaultModel.isEmpty ? nil : defaultModel,
                        modelProvider: defaultModelProvider.isEmpty ? nil : defaultModelProvider,
                        attachments: attachments,
                        profile: "default"
                    )
                )
                if let title = response.title, !title.isEmpty {
                    chat.sessionTitle = title
                }
                upsertSessionSummary(sessionID: sessionID, title: response.title ?? chat.sessionTitle, activeStreamID: response.streamId)
                if let streamId = response.streamId {
                    attachStream(streamID: streamId, sessionID: sessionID)
                } else {
                    await loadSession(sessionID: sessionID)
                }
            } catch HermesError.conflictActiveStream(let activeStreamID) {
                if let streamID = activeStreamID {
                    attachStream(streamID: streamID, sessionID: sessionID)
                    await refreshPendingPrompts(sessionID: sessionID)
                } else {
                    await loadSession(sessionID: sessionID)
                }
            } catch {
                // Message sent, but client HTTP cancelled (re-render race).
                // Backend processed it. Silently reload.
                if case HermesError.transport(let msg) = error, msg == "cancelled" {
                    await loadSession(sessionID: sessionID)
                    return
                }
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    await loadSession(sessionID: sessionID)
                    return
                }
                chat.lastError = readableError(error)
                await loadSession(sessionID: sessionID)
            }
        } catch {
            chat.lastError = readableError(error)
        }
    }

    func cancelCurrentStream() async {
        guard let streamID = chat.activeStreamID else { return }
        do {
            let client = try requireAPIClient()
            _ = try await client.cancelStream(streamID: streamID)
        } catch {
            chat.lastError = readableError(error)
        }
        stopLocalStream()
        if let currentSessionID {
            await loadSession(sessionID: currentSessionID)
        }
    }

    func respondApproval(choice: String) async {
        guard let sessionID = currentSessionID else { return }
        guard let pendingApproval = chat.pendingApproval else { return }

        do {
            let client = try requireAPIClient()
            let response = try await client.respondApproval(
                request: ApprovalRespondRequestDTO(
                    sessionId: sessionID,
                    choice: choice,
                    approvalId: pendingApproval.approvalId
                )
            )
            if response.ok {
                chat.pendingApproval = nil
                chat.pendingApprovalCount = 0
                chat.lastError = nil
            }
            await refreshPendingPrompts(sessionID: sessionID)
        } catch {
            chat.lastError = readableError(error)
        }
    }

    func respondClarify() async {
        guard let sessionID = currentSessionID else { return }
        guard let pendingClarify = chat.pendingClarify else { return }
        let responseText = chat.clarifyResponseDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !responseText.isEmpty else { return }

        do {
            let client = try requireAPIClient()
            let response = try await client.respondClarify(
                request: ClarifyRespondRequestDTO(
                    sessionId: sessionID,
                    response: responseText,
                    clarifyId: pendingClarify.clarifyId
                )
            )
            guard response.ok else {
                chat.lastError = response.error ?? "Clarification response not accepted."
                return
            }
            chat.messages.append(MessageDTO(role: "user", content: .text(responseText), timestamp: Date().timeIntervalSince1970))
            chat.pendingClarify = nil
            chat.clarifyResponseDraft = ""
            chat.lastError = nil
            await refreshPendingPrompts(sessionID: sessionID)
        } catch {
            chat.lastError = readableError(error)
        }
    }

    func openSettings() {
        route = .settings
    }

    func showSessions() {
        route = .sessions
    }

    func logout() async {
        stopLocalStream()
        do {
            let client = try requireAPIClient()
            try await client.logout()
        } catch {
            auth.lastError = readableError(error)
        }
        credentialStore.clearCookies()
        auth.isLoggedIn = false
        currentSessionID = nil
        isNewChatQueued = false
        chat = ChatStore()
        sessions.items = []
        route = .login
    }

    private func ensureSessionID() async throws -> String {
        if let currentSessionID {
            return currentSessionID
        }
        let client = try requireAPIClient()
        let payload = try await client.createSession(
            request: CreateSessionRequestDTO(workspace: nil, model: defaultModel.isEmpty ? nil : defaultModel, modelProvider: defaultModelProvider.isEmpty ? nil : defaultModelProvider, profile: "default")
        )
        currentSessionID = payload.session.sessionId
        isNewChatQueued = false
        route = .chat
        applySession(payload.session)
        upsertSessionSummary(from: payload.session)
        return payload.session.sessionId
    }

    private func reattachStreamIfNeeded(streamID: String, sessionID: String) async {
        do {
            let client = try requireAPIClient()
            let status = try await client.streamStatus(streamID: streamID)
            if status.active {
                attachStream(streamID: streamID, sessionID: sessionID)
                await refreshPendingPrompts(sessionID: sessionID)
            } else {
                let payload = try await client.fetchSession(sessionID: sessionID, includeMessages: true, limit: nil)
                applySession(payload.session)
                await refreshPendingPrompts(sessionID: sessionID)
            }
        } catch {
            chat.lastError = readableError(error)
        }
    }

    private func attachStream(streamID: String, sessionID: String) {
        stopLocalStream()
        logStreamDebug("attachStream streamID=\(streamID) sessionID=\(sessionID)")
        chat.activeStreamID = streamID
        chat.isStreaming = true
        didReceiveDoneForActiveStream = false
        upsertSessionSummary(sessionID: sessionID, title: chat.sessionTitle, activeStreamID: streamID)

        let stream = requireAPIClientOrNil()?.streamChat(streamID: streamID)
        streamTask = Task { [weak self] in
            guard let self, let stream else { return }
            do {
                for try await event in stream {
                    self.handleStreamEvent(event, sessionID: sessionID, streamID: streamID)
                }
                self.logStreamDebug("stream iteration ended streamID=\(streamID)")
                await self.finishStreamIfNeeded(sessionID: sessionID, streamID: streamID)
            } catch {
                self.logStreamError("stream failed streamID=\(streamID) error=\(String(describing: error))")
                await self.handleStreamFailure(error, sessionID: sessionID, streamID: streamID)
            }
        }
    }

    private func handleStreamEvent(_ event: HermesStreamEvent, sessionID: String, streamID: String) {
        guard currentSessionID == sessionID else { return }

        switch event {
        case .token(let token):
            logStreamDebug("SSE token streamID=\(streamID) chars=\(token.count) text=\(token)")
            chat.isAwaitingAssistantStart = false
            chat.activeToolCall = nil
            appendAssistantVisibleText(token)
        case .title(let payload):
            if !payload.title.isEmpty {
                chat.sessionTitle = payload.title
                upsertSessionSummary(sessionID: sessionID, title: payload.title, activeStreamID: streamID)
            }
        case .done(let payload):
            logStreamDebug("SSE done streamID=\(streamID) messages=\(payload.session.messages.count)")
            didReceiveDoneForActiveStream = true
            chat.isAwaitingAssistantStart = false
            chat.activeToolCall = nil
            // Finalize tool steps: move pending → completed
            let stepsToFinalize = chat.pendingToolSteps
            chat.pendingToolSteps = []
            if !stepsToFinalize.isEmpty {
                completedToolSteps = stepsToFinalize
                logStreamDebug("Finalized \(stepsToFinalize.count) tool steps")
            }
            resetPromptState()
            applySession(payload.session)
        case .appError(let payload):
            logStreamError("SSE apperror streamID=\(streamID) label=\(payload.label ?? "") message=\(payload.message ?? "")")
            chat.isAwaitingAssistantStart = false
            chat.lastError = [payload.label, payload.message, payload.hint].compactMap { $0 }.joined(separator: " — ")
        case .cancel:
            logStreamDebug("SSE cancel streamID=\(streamID)")
            chat.isAwaitingAssistantStart = false
            chat.isStreaming = false
            chat.activeToolCall = nil
            if !chat.pendingToolSteps.isEmpty {
                completedToolSteps = chat.pendingToolSteps
                chat.pendingToolSteps = []
            }
        case .streamEnd:
            logStreamDebug("SSE stream_end streamID=\(streamID)")
            chat.isAwaitingAssistantStart = false
            chat.isStreaming = false
            chat.activeToolCall = nil
            if !chat.pendingToolSteps.isEmpty {
                completedToolSteps = chat.pendingToolSteps
                chat.pendingToolSteps = []
            }
        case .approval(let payload):
            chat.pendingApproval = payload
            chat.pendingApprovalCount = max(chat.pendingApprovalCount, 1)
            chat.lastError = nil
            Task { [weak self] in
                await self?.refreshPendingPrompts(sessionID: sessionID)
            }
        case .clarify(let payload):
            chat.pendingClarify = payload
            chat.lastError = nil
            Task { [weak self] in
                await self?.refreshPendingPrompts(sessionID: sessionID)
            }
        case .toolStart(let event):
            logStreamDebug("SSE tool streamID=\(streamID) name=\(event.name)")
            chat.activeToolCall = ActiveToolCall(name: event.name, preview: event.preview, args: event.args)
            // Accumulate step immediately so it's tracked even if stream ends early
            chat.pendingToolSteps.append(ToolCallStep(
                name: event.name,
                preview: event.preview,
                args: event.args,
                status: .complete
            ))
        case .toolComplete(let event):
            logStreamDebug("SSE tool_complete streamID=\(streamID) name=\(event.name)")
            chat.activeToolCall = nil
            // Update the last matching step's status if it was an error
            if event.isError {
                if let idx = chat.pendingToolSteps.lastIndex(where: { $0.name == event.name }) {
                    chat.pendingToolSteps[idx].status = .error
                }
            }
        case .reasoning, .contextStatus, .unknown:
            break
        }
    }

    private func finishStreamIfNeeded(sessionID: String, streamID: String) async {
        guard currentSessionID == sessionID else { return }
        stopLocalStream(cancelTask: false)
        resetPromptState()
        upsertSessionSummary(sessionID: sessionID, title: chat.sessionTitle, activeStreamID: nil)
        if didReceiveDoneForActiveStream {
            didReceiveDoneForActiveStream = false
            await refreshSessions()
            return
        }
        do {
            let client = try requireAPIClient()
            let payload = try await client.fetchSession(sessionID: sessionID, includeMessages: true, limit: nil)
            applySession(payload.session)
            await refreshSessions()
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }
            if case HermesError.transport(let message) = error, message == "cancelled" {
                return
            }
            chat.lastError = readableError(error)
        }
    }

    private func handleStreamFailure(_ error: Error, sessionID: String, streamID: String) async {
        guard currentSessionID == sessionID, chat.activeStreamID == streamID else { return }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            stopLocalStream(cancelTask: false)
            return
        }
        if case HermesError.transport(let message) = error, message == "cancelled" {
            stopLocalStream(cancelTask: false)
            return
        }

        stopLocalStream(cancelTask: false)
        chat.lastError = readableError(error)
        do {
            let client = try requireAPIClient()
            let payload = try await client.fetchSession(sessionID: sessionID, includeMessages: true, limit: nil)
            applySession(payload.session)
            await refreshPendingPrompts(sessionID: sessionID)
            await refreshSessions()
        } catch {
            chat.lastError = readableError(error)
        }
    }

    private func refreshPendingPrompts(sessionID: String) async {
        do {
            let client = try requireAPIClient()
            async let approvalEnvelope = client.fetchPendingApproval(sessionID: sessionID)
            async let clarifyEnvelope = client.fetchPendingClarify(sessionID: sessionID)
            let (approval, clarify) = try await (approvalEnvelope, clarifyEnvelope)
            guard currentSessionID == sessionID else { return }
            chat.pendingApproval = approval.pending
            chat.pendingApprovalCount = approval.pending == nil ? 0 : max(approval.pendingCount ?? 1, 1)
            chat.pendingClarify = clarify.pending
            if clarify.pending == nil {
                chat.clarifyResponseDraft = ""
            }
        } catch {
            guard currentSessionID == sessionID else { return }
            chat.lastError = readableError(error)
        }
    }

    private func applySession(_ session: SessionDTO) {
        currentSessionID = session.sessionId
        chat.sessionTitle = session.title.isEmpty ? "Chat" : session.title
        chat.sessionModel = session.model
        chat.sessionProfile = session.profile
        chat.sessionUpdatedAt = session.updatedAt ?? session.lastMessageAt ?? session.pendingStartedAt
        
        // Merge server messages with local messages to preserve local IDs during streaming transition.
        // This prevents the "stutter" when the server message replaces the locally accumulated message.
        chat.messages = mergeMessages(local: chat.messages, server: session.messages)
        
        chat.activeStreamID = session.activeStreamId
        chat.isStreaming = session.activeStreamId != nil
        chat.isAwaitingAssistantStart = false
        chat.isLoading = false
        // Populate completedToolSteps from session tool_calls.
        // Only update when server provides data — don't wipe steps set from pendingToolSteps.
        if let toolCalls = session.toolCalls {
            completedToolSteps = toolCalls.compactMap { tc in
                guard let name = tc.name else { return nil }
                let status: ToolCallStep.Status = tc.isError == true ? .error : .complete
                return ToolCallStep(
                    name: name,
                    preview: tc.preview,
                    args: tc.args ?? [:],
                    status: status
                )
            }
        }
        upsertSessionSummary(from: session)
    }
    
    /// Merges server messages with local messages, preserving local IDs when displayed content matches.
    /// This prevents SwiftUI from treating the transition as removing/adding rows.
    private func mergeMessages(local: [MessageDTO], server: [MessageDTO]) -> [MessageDTO] {
        guard !local.isEmpty else { return server }
        
        var result: [MessageDTO] = []
        var localIndex = 0
        
        for serverMsg in server {
            // Try to find a matching local message
            if localIndex < local.count {
                let localMsg = local[localIndex]
                
                // Match by role and displayed content
                if localMsg.role == serverMsg.role && localMsg.displayText == serverMsg.displayText {
                    // Keep the local message (preserves ID for smooth SwiftUI transition)
                    result.append(localMsg)
                    localIndex += 1
                    continue
                }
            }
            
            // No match found, use server message
            result.append(serverMsg)
        }
        
        return result
    }

    private func applySessionIfNeeded(_ session: SessionDTO) {
        if currentSessionID == session.sessionId {
            applySession(session)
        } else {
            upsertSessionSummary(from: session)
        }
    }

    private func upsertSessionSummary(from session: SessionDTO) {
        let existing = sessions.items.first(where: { $0.sessionId == session.sessionId })
        let summary = SessionSummaryDTO(
            sessionId: session.sessionId,
            title: session.title,
            messageCount: session.messageCount,
            updatedAt: session.updatedAt ?? session.pendingStartedAt ?? existing?.updatedAt,
            lastMessageAt: session.lastMessageAt ?? session.pendingStartedAt ?? existing?.lastMessageAt,
            model: session.model ?? existing?.model,
            profile: session.profile ?? existing?.profile,
            activeStreamId: session.activeStreamId
        )
        upsertSessionSummary(summary)
    }

    private func upsertSessionSummary(sessionID: String, title: String, activeStreamID: String?) {
        let existing = sessions.items.first(where: { $0.sessionId == sessionID })
        let now = Date().timeIntervalSince1970
        let summary = SessionSummaryDTO(
            sessionId: sessionID,
            title: title.isEmpty ? (existing?.title ?? "Untitled") : title,
            messageCount: existing?.messageCount ?? 0,
            updatedAt: now,
            lastMessageAt: now,
            model: existing?.model,
            profile: existing?.profile,
            activeStreamId: activeStreamID
        )
        upsertSessionSummary(summary)
    }

    private func upsertSessionSummary(_ summary: SessionSummaryDTO) {
        if let index = sessions.items.firstIndex(where: { $0.sessionId == summary.sessionId }) {
            sessions.items[index] = summary
        } else {
            sessions.items.insert(summary, at: 0)
        }
        sessions.items.sort(by: sessionSort)
    }

    private func sessionSort(lhs: SessionSummaryDTO, rhs: SessionSummaryDTO) -> Bool {
        let left = lhs.lastMessageAt ?? lhs.updatedAt ?? 0
        let right = rhs.lastMessageAt ?? rhs.updatedAt ?? 0
        if left == right {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return left > right
    }

    private func resetPromptState() {
        chat.pendingApproval = nil
        chat.pendingApprovalCount = 0
        chat.pendingClarify = nil
        chat.clarifyResponseDraft = ""
    }

    private func appendAssistantVisibleText(_ text: String) {
        guard !text.isEmpty else { return }
        if let lastIndex = chat.messages.lastIndex(where: { $0.role == "assistant" }) {
            let existing = chat.messages[lastIndex]
            let current = existing.displayText
            chat.messages[lastIndex] = MessageDTO(id: existing.id, role: "assistant", content: .text(current + text), timestamp: Date().timeIntervalSince1970, attachments: existing.attachments)
        } else {
            chat.messages.append(MessageDTO(role: "assistant", content: .text(text), timestamp: Date().timeIntervalSince1970))
        }
    }

    private func stopLocalStream(cancelTask: Bool = true) {
        if cancelTask {
            streamTask?.cancel()
        }
        streamTask = nil
        chat.activeStreamID = nil
        chat.isStreaming = false
        chat.isAwaitingAssistantStart = false
        chat.activeToolCall = nil
    }

    private func requireAPIClient() throws -> HermesAPIClientProtocol {
        guard let apiClient else {
            throw HermesError.invalidURL
        }
        return apiClient
    }

    private func requireAPIClientOrNil() -> HermesAPIClientProtocol? {
        apiClient
    }

    private func readableError(_ error: Error) -> String {
        if let hermesError = error as? HermesError {
            return hermesError.localizedDescription
        }
        return error.localizedDescription
    }

    private func logStreamDebug(_ message: String) {
        guard isStreamDebugLoggingEnabled else { return }
        logger.debug("\(message, privacy: .public)")
    }

    private func logStreamError(_ message: String) {
        guard isStreamDebugLoggingEnabled else { return }
        logger.error("\(message, privacy: .public)")
    }
}
