import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    let sessionID: String?
    @Binding var showSidebar: Bool

    @State private var showRenameSheet = false
    @State private var renameDraft = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var isComposerFocused: Bool

    // ── Emil's custom ease-out curve ──
    private let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
    private let easeOutFast = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)

    private var contentOffset: CGFloat { showSidebar ? 60 : 0 }

    private var currentTitle: String {
        let trimmed = appState.chat.sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Chat" : trimmed
    }

    private var hasRealSession: Bool {
        appState.currentSessionID != nil
    }

    var body: some View {
        @Bindable var appState = appState

        GeometryReader { proxy in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                // Approval / Clarify banners
                if let approval = appState.chat.pendingApproval {
                    approvalCard(approval)
                }
                if let clarify = appState.chat.pendingClarify {
                    clarifyCard(clarify, draft: $appState.chat.clarifyResponseDraft)
                }

                // Messages
                if appState.chat.isLoading {
                    Spacer()
                    ContentUnavailableView(
                        "Loading Chat...",
                        systemImage: "bubble.left.and.text.bubble.right"
                    )
                    Spacer()
                } else if appState.chat.messages.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Messages Yet",
                        systemImage: "bubble.left.and.text.bubble.right"
                    )
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        List(Array(appState.chat.messages.enumerated()), id: \.element.id) { index, message in
                            MessageRow(
                                message: message,
                                isStreaming: appState.chat.isStreaming
                                    && index == appState.chat.messages.indices.last
                                    && message.role == "assistant"
                            )
                            .id(message.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .onChange(of: appState.chat.messages.count) { _, _ in
                            if let last = appState.chat.messages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: appState.chat.messages.last?.displayText ?? "") { _, _ in
                            if let last = appState.chat.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Error
                if let error = appState.chat.lastError {
                    Divider()
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                }

                // ── Liquid glass composer ──
                composer(appState: appState)
                }
                .safeAreaPadding(.top, 72)
                .offset(x: contentOffset)
                .animation(showSidebar ? easeOut : easeOutFast, value: contentOffset)

                topHeaderBackdrop(topInset: proxy.safeAreaInsets.top)
                    .allowsHitTesting(false)

                floatingHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                focusComposerSoon()
            }
            .onChange(of: appState.currentSessionID) { _, _ in
                focusComposerSoon()
            }
            .onChange(of: appState.route) { _, route in
                if route == .chat {
                    focusComposerSoon()
                }
            }
            .alert("Delete session?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                guard let sessionID = appState.currentSessionID else { return }
                Task {
                    await appState.deleteSession(sessionID: sessionID)
                }
            }
            Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes current session.")
            }
            .sheet(isPresented: $showRenameSheet) {
                renameSheet
            }
        }
    }

    private var floatingHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismissKeyboard()
                withAnimation(showSidebar ? easeOutFast : easeOut) {
                    showSidebar.toggle()
                }
            } label: {
                headerCircleButton(systemName: showSidebar ? "xmark" : "line.3.horizontal")
            }
            .buttonStyle(.plain)

            Text(currentTitle)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasRealSession {
                Menu {
                    Section {
                        Button {
                            renameDraft = currentTitle
                            showRenameSheet = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button {
                            guard let sessionID = appState.currentSessionID else { return }
                            Task {
                                await appState.archiveSession(sessionID: sessionID)
                                appState.startNewChatQueue()
                            }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } header: {
                        Text(appState.currentSessionID ?? "Session ID unavailable")
                            .font(.caption)
                    }
                } label: {
                    headerCircleButton(systemName: "ellipsis")
                }
                .buttonStyle(.plain)
                .menuStyle(.button)
            }
        }
        .frame(minHeight: 56)
    }

    private func topHeaderBackdrop(topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            FadingBlurOverlay()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.60),
                    Color.black.opacity(0.26),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: topInset + 56 + 52)
        .ignoresSafeArea(edges: .top)
    }

    private func headerCircleButton(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(.white.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .white.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: 46, height: 46)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func focusComposerSoon() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            if !showSidebar {
                isComposerFocused = true
            }
        }
    }

    // MARK: - Composer

    @ViewBuilder
    private func composer(appState: AppState) -> some View {
        @Bindable var appState = appState

        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                appState.chat.pendingClarify == nil ? "Message" : "Respond above to continue",
                text: $appState.chat.draft,
                axis: .vertical
            )
            .font(.body)
            .lineLimit(1...6)
            .disabled(appState.chat.pendingClarify != nil)
            .focused($isComposerFocused)
            .submitLabel(.send)
            .onSubmit {
                guard canSend(appState) else { return }
                Task { await appState.sendChat() }
            }

            Button {
                Task {
                    if appState.chat.isStreaming {
                        await appState.cancelCurrentStream()
                    } else {
                        await appState.sendChat()
                    }
                    isComposerFocused = true
                }
            } label: {
                Image(systemName: appState.chat.isStreaming
                    ? "stop.fill"
                    : "arrow.up")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .disabled(!canSend(appState))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.top, 6)
    }

    private func canSend(_ appState: AppState) -> Bool {
        if appState.chat.isStreaming { return true }
        if appState.chat.isLoading { return false }
        if appState.chat.pendingClarify != nil { return false }
        return !appState.chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var renameSheet: some View {
        NavigationStack {
            Form {
                Section("Rename Session") {
                    TextField("Title", text: $renameDraft)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRenameSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let sessionID = appState.currentSessionID else { return }
                        let title = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            await appState.renameSession(sessionID: sessionID, title: title)
                            showRenameSheet = false
                        }
                    }
                    .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasRealSession)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Approval / Clarify

    @ViewBuilder
    private func approvalCard(_ approval: ApprovalPendingDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Approval Required", systemImage: "exclamationmark.shield")
                    .font(.headline)
                Spacer()
                if appState.chat.pendingApprovalCount > 1 {
                    Text("1 of \(appState.chat.pendingApprovalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = approval.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
            }

            if let command = approval.command, !command.isEmpty {
                Text(command)
                    .font(.footnote.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Button("Once") { Task { await appState.respondApproval(choice: "once") } }
                Button("Session") { Task { await appState.respondApproval(choice: "session") } }
                Button("Always") { Task { await appState.respondApproval(choice: "always") } }
                Button("Deny", role: .destructive) { Task { await appState.respondApproval(choice: "deny") } }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func clarifyCard(_ clarify: ClarifyPendingDTO, draft: Binding<String>) -> some View {
        let choices = clarify.choicesOffered ?? clarify.choices ?? []

        VStack(alignment: .leading, spacing: 10) {
            Label("Clarification Needed", systemImage: "questionmark.bubble")
                .font(.headline)

            Text(clarify.question ?? clarify.description ?? "Reply to continue.")
                .font(.subheadline)

            if !choices.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(choices, id: \.self) { choice in
                            Button(choice) {
                                draft.wrappedValue = choice
                                Task { await appState.respondClarify() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type your response", text: draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button("Reply") {
                    Task { await appState.respondClarify() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: MessageDTO
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Role indicator
            Circle()
                .fill(message.role == "user" ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: message.role == "user" ? "person.fill" : "brain")
                        .font(.caption2)
                        .foregroundStyle(message.role == "user" ? .white : .secondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(message.role == "user" ? "You" : "Assistant")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let timestamp = message.timestamp {
                        Text(Self.timestampFormatter.localizedString(for: Date(timeIntervalSince1970: timestamp), relativeTo: Date()))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if isStreaming && message.displayText.isEmpty {
                    StreamingDotsView()
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(message.displayText.isEmpty && message.role == "assistant"
                             ? "Thinking..."
                             : message.displayText)
                            .font(.body)
                            .textSelection(.enabled)

                        if isStreaming {
                            StreamingCursorView()
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private static let timestampFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

private struct StreamingDotsView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate * 2.5) % 3
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(index <= phase ? 0.95 : 0.3)
                        .scaleEffect(index == phase ? 1 : 0.82)
                }
            }
            .frame(height: 20, alignment: .leading)
        }
    }
}

private struct StreamingCursorView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let visible = Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(.secondary)
                .frame(width: 2, height: 16)
                .opacity(visible ? 1 : 0.15)
                .padding(.bottom, 1)
        }
    }
}

private struct FadingBlurOverlay: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        effectView.isUserInteractionEnabled = false

        let alphaMask = CAGradientLayer()
        alphaMask.colors = [
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0.92).cgColor,
            UIColor.black.withAlphaComponent(0.42).cgColor,
            UIColor.clear.cgColor
        ]
        alphaMask.locations = [0, 0.28, 0.76, 1]
        alphaMask.startPoint = CGPoint(x: 0.5, y: 0)
        alphaMask.endPoint = CGPoint(x: 0.5, y: 1)
        effectView.layer.mask = alphaMask

        context.coordinator.alphaMask = alphaMask
        return effectView
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        context.coordinator.alphaMask?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var alphaMask: CAGradientLayer?
    }
}
