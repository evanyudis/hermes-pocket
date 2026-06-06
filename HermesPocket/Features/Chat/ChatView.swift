import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct ChatView: View {
    @Environment(AppState.self) private var appState
    let sessionID: String?
    @Binding var showSidebar: Bool

    @State private var showRenameSheet = false
    @State private var renameDraft = ""
    @State private var showDeleteConfirmation = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
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

                }
                .safeAreaPadding(.top, 72)
                .offset(x: contentOffset)
                .animation(showSidebar ? easeOut : easeOutFast, value: contentOffset)

                VStack {
                    Spacer()
                    // ── Floating liquid glass composer ──
                    composer(appState: appState)
                }
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
        let hasDraft = !appState.chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isExpanded = hasDraft || !appState.chat.stagedAttachments.isEmpty

        VStack(alignment: .leading, spacing: 10) {
            if !appState.chat.stagedAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appState.chat.stagedAttachments, id: \.path) { attachment in
                            attachmentChip(attachment) {
                                appState.chat.stagedAttachments.removeAll { $0.path == attachment.path }
                            }
                        }
                    }
                }
            }

            TextField(
                appState.chat.pendingClarify == nil ? "Send a message..." : "Respond above to continue",
                text: $appState.chat.draft,
                axis: .vertical
            )
            .font(.system(size: 17, weight: hasDraft ? .semibold : .regular))
            .foregroundStyle(.primary)
            .lineLimit(1...6)
            .disabled(appState.chat.pendingClarify != nil)
            .focused($isComposerFocused)
            .submitLabel(.send)
            .onSubmit {
                guard canSend(appState) else { return }
                Task { await appState.sendChat() }
            }

            HStack(alignment: .center, spacing: 12) {
                attachmentMenu(appState: appState)

                modelSelector(appState: appState)

                Spacer(minLength: 6)

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
                    Image(systemName: appState.chat.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(sendButtonForeground(appState))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(sendButtonBackground(appState))
                                .environment(\.colorScheme, .dark)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend(appState))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, isExpanded ? 14 : 12)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 16, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.top, 0)
        .animation(easeOut, value: isExpanded)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                appendFileAttachments(urls, to: appState)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .any(of: [.images, .videos]))
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                appendCameraAttachment(image, to: appState)
                showCamera = false
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await appendPhotoAttachment(item, to: appState) }
        }
        .task {
            if appState.availableModels.isEmpty && !appState.isFetchingModels {
                await appState.fetchModels()
            }
        }
    }

    private func canSend(_ appState: AppState) -> Bool {
        if appState.chat.isStreaming { return true }
        if appState.chat.isLoading { return false }
        if appState.chat.pendingClarify != nil { return false }
        return !appState.chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !appState.chat.stagedAttachments.isEmpty
    }

    private func sendButtonForeground(_ appState: AppState) -> Color {
        canSend(appState) ? .white : .white.opacity(0.32)
    }

    private func sendButtonBackground(_ appState: AppState) -> AnyShapeStyle {
        canSend(appState)
            ? AnyShapeStyle(Color.accentColor.gradient)
            : AnyShapeStyle(.ultraThinMaterial)
    }

    private func attachmentMenu(appState: AppState) -> some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }

            Button { showPhotoPicker = true } label: {
                Label("From Library", systemImage: "photo.on.rectangle")
            }

            Button { showFileImporter = true } label: {
                Label("Upload File", systemImage: "doc.badge.plus")
            }
        } label: {
            addControl
        }
        .menuStyle(.button)
    }

    private func modelSelector(appState: AppState) -> some View {
        Menu {
            Button {
                appState.defaultModel = ""
                appState.defaultModelProvider = ""
                appState.credentialStore.saveDefaultModel("")
                appState.credentialStore.saveDefaultModelProvider("")
            } label: {
                Label("Use server default", systemImage: appState.defaultModel.isEmpty ? "checkmark" : "circle")
            }

            ForEach(appState.availableModels, id: \.providerId) { group in
                Section(group.provider ?? group.providerId ?? "Models") {
                    ForEach(group.models ?? []) { entry in
                        Button {
                            appState.defaultModel = entry.id
                            appState.defaultModelProvider = group.providerId ?? group.provider ?? ""
                            appState.credentialStore.saveDefaultModel(entry.id)
                            appState.credentialStore.saveDefaultModelProvider(appState.defaultModelProvider)
                        } label: {
                            Label(entry.label ?? entry.id, systemImage: appState.defaultModel == entry.id ? "checkmark" : "circle")
                        }
                    }
                }
            }
        } label: {
            modelControl(title: selectedModelTitle(appState))
        }
        .menuStyle(.button)
    }

    private func selectedModelTitle(_ appState: AppState) -> String {
        guard !appState.defaultModel.isEmpty else { return appState.serverDefaultModel ?? "Model" }
        return appState.availableModels
            .flatMap { $0.models ?? [] }
            .first { $0.id == appState.defaultModel }?
            .label ?? appState.defaultModel
    }

    private var addControl: some View {
        Image(systemName: "plus")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
    }

    private func modelControl(title: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.regular))
                .lineLimit(1)
                .truncationMode(.tail)
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.white.opacity(0.82))
        .frame(maxWidth: 144, alignment: .leading)
        .frame(height: 32)
        .contentShape(Rectangle())
    }

    private func attachmentChip(_ attachment: AttachmentDTO, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            attachmentPreview(attachment)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(attachment.mime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 132, alignment: .leading)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 5)
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func attachmentPreview(_ attachment: AttachmentDTO) -> some View {
        let cornerRadius: CGFloat = 8

        if attachment.mime.hasPrefix("image/"),
           let image = UIImage(contentsOfFile: attachment.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fileFormatGradient(for: attachment))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: fileFormatIcon(for: attachment))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                )
        }
    }

    private func fileFormatIcon(for attachment: AttachmentDTO) -> String {
        switch fileFormatKind(for: attachment) {
        case .pdf:
            return "doc.richtext"
        case .sheet:
            return "tablecells"
        case .text:
            return "doc.text"
        case .archive:
            return "doc.zipper"
        case .other:
            return "doc"
        }
    }

    private func fileFormatGradient(for attachment: AttachmentDTO) -> LinearGradient {
        let base: Color
        switch fileFormatKind(for: attachment) {
        case .pdf:
            base = Color(hex: "490908")
        case .text:
            base = Color(hex: "043A4E")
        case .sheet:
            base = Color(hex: "153C17")
        case .archive:
            base = Color(hex: "5F4C07")
        case .other:
            base = Color(hex: "2A2A2C")
        }

        return LinearGradient(
            colors: [base.opacity(0.98), base.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func fileFormatKind(for attachment: AttachmentDTO) -> FileFormatKind {
        let ext = URL(fileURLWithPath: attachment.name).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return .pdf
        case "csv", "xls", "xlsx", "numbers":
            return .sheet
        case "doc", "docx", "pages", "txt", "md", "rtf":
            return .text
        case "zip", "tar", "gz":
            return .archive
        default:
            return .other
        }
    }

    private func appendFileAttachments(_ urls: [URL], to appState: AppState) {
        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let type = UTType(filenameExtension: url.pathExtension)
            let mime = type?.preferredMIMEType ?? "application/octet-stream"
            appState.chat.stagedAttachments.append(AttachmentDTO(name: url.lastPathComponent, path: url.path, mime: mime))
        }
    }

    private func appendCameraAttachment(_ image: UIImage, to appState: AppState) {
        let url = FileManager.default.temporaryDirectory.appending(path: "hermes-photo-\(UUID().uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.86) {
            try? data.write(to: url)
        }
        appState.chat.stagedAttachments.append(AttachmentDTO(name: url.lastPathComponent, path: url.path, mime: "image/jpeg"))
    }

    private func appendPhotoAttachment(_ item: PhotosPickerItem, to appState: AppState) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let contentType = item.supportedContentTypes.first
        let ext = contentType?.preferredFilenameExtension ?? "jpg"
        let mime = contentType?.preferredMIMEType ?? "image/jpeg"
        let url = FileManager.default.temporaryDirectory.appending(path: "hermes-library-\(UUID().uuidString).\(ext)")
        try? data.write(to: url)
        appState.chat.stagedAttachments.append(AttachmentDTO(name: url.lastPathComponent, path: url.path, mime: mime))
        photoPickerItem = nil
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

private enum FileFormatKind {
    case pdf
    case text
    case sheet
    case archive
    case other
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
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
