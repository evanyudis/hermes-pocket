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
    @State private var composerHeight: CGFloat = 74
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
                    ApprovalCardView(approval: approval, pendingApprovalCount: appState.chat.pendingApprovalCount) { choice in
                        Task { await appState.respondApproval(choice: choice) }
                    }
                }
                if let clarify = appState.chat.pendingClarify {
                    ClarifyCardView(clarify: clarify, draft: $appState.chat.clarifyResponseDraft) { choice in
                        appState.chat.clarifyResponseDraft = choice
                        Task { await appState.respondClarify() }
                    } onReply: {
                        Task { await appState.respondClarify() }
                    }
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
                            MessageRowView(
                                message: message,
                                isStreaming: appState.chat.isStreaming
                                    && index == appState.chat.messages.indices.last
                                    && message.role == "assistant",
                                isAwaitingStart: appState.chat.isAwaitingAssistantStart
                                    && index == appState.chat.messages.indices.last
                                    && message.role == "assistant",
                                previousRole: index > 0 ? appState.chat.messages[index - 1].role : nil
                            )
                            .id(message.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                dismissKeyboard()
                                isComposerFocused = false
                            }
                        )
                        .onAppear {
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                        .onChange(of: appState.currentSessionID) { _, _ in
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(80))
                                scrollToBottom(proxy: proxy, animated: false)
                            }
                        }
                        .onChange(of: appState.chat.isLoading) { _, isLoading in
                            guard !isLoading else { return }
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(40))
                                scrollToBottom(proxy: proxy, animated: false)
                            }
                        }
                        .onChange(of: appState.chat.messages.count) { _, _ in
                            scrollToBottom(proxy: proxy, animated: true)
                        }
                        .onChange(of: appState.chat.messages.last?.displayText ?? "") { _, _ in
                            scrollToBottom(proxy: proxy, animated: false)
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
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                    isComposerFocused = false
                }
                .safeAreaPadding(.top, 72)
                .safeAreaPadding(.bottom, composerHeight + 24)
                .offset(x: contentOffset)
                .animation(showSidebar ? easeOut : easeOutFast, value: contentOffset)

                VStack {
                    Spacer()
                    // ── Floating liquid glass composer ──
                    composer
                }
                .offset(x: contentOffset)
                .animation(showSidebar ? easeOut : easeOutFast, value: contentOffset)

                topHeaderBackdrop(topInset: proxy.safeAreaInsets.top)
                    .allowsHitTesting(false)

                header
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

    private var header: some View {
        ChatHeaderView(
            title: currentTitle,
            hasRealSession: hasRealSession,
            sessionID: appState.currentSessionID,
            showSidebar: showSidebar,
            onToggleSidebar: {
                dismissKeyboard()
                withAnimation(showSidebar ? easeOutFast : easeOut) {
                    showSidebar.toggle()
                }
            },
            onRename: {
                renameDraft = currentTitle
                showRenameSheet = true
            },
            onArchive: {
                guard let sessionID = appState.currentSessionID else { return }
                Task {
                    await appState.archiveSession(sessionID: sessionID)
                    appState.startNewChatQueue()
                }
            },
            onDelete: {
                showDeleteConfirmation = true
            }
        )
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

    private func dismissKeyboard() {
        NotificationCenter.default.post(name: .chatDismissTextSelection, object: nil)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = appState.chat.messages.last else { return }
        if animated {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
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

    private var composer: some View {
        @Bindable var appState = appState

        return ChatComposerView(
            draft: $appState.chat.draft,
            stagedAttachments: $appState.chat.stagedAttachments,
            photoPickerItem: $photoPickerItem,
            pendingClarify: appState.chat.pendingClarify,
            isStreaming: appState.chat.isStreaming,
            isLoading: appState.chat.isLoading,
            availableModels: appState.availableModels,
            isFetchingModels: appState.isFetchingModels,
            defaultModel: appState.defaultModel,
            serverDefaultModel: appState.serverDefaultModel,
            easeOut: easeOut,
            onAttachmentMenuTapCamera: {
                showCamera = true
            },
            onAttachmentMenuTapPhotoLibrary: {
                showPhotoPicker = true
            },
            onAttachmentMenuTapFile: {
                showFileImporter = true
            },
            onSelectServerDefaultModel: {
                appState.defaultModel = ""
                appState.defaultModelProvider = ""
                appState.credentialStore.saveDefaultModel("")
                appState.credentialStore.saveDefaultModelProvider("")
            },
            onSelectModel: { providerID, modelID in
                appState.defaultModel = modelID
                appState.defaultModelProvider = providerID
                appState.credentialStore.saveDefaultModel(modelID)
                appState.credentialStore.saveDefaultModelProvider(providerID)
            },
            onSend: {
                Task {
                    await appState.sendChat()
                    isComposerFocused = true
                }
            },
            onStop: {
                Task {
                    await appState.cancelCurrentStream()
                    isComposerFocused = true
                }
            },
            onFetchModels: {
                await appState.fetchModels()
            },
            onHeightChange: { height in
                composerHeight = height
            },
            focus: $isComposerFocused
        )
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
    }

    private func appendFileAttachments(_ urls: [URL], to appState: AppState) {
        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let type = UTType(filenameExtension: url.pathExtension)
            let mime = type?.preferredMIMEType ?? "application/octet-stream"
            withAnimation(easeOut) {
                appState.chat.stagedAttachments.append(AttachmentDTO(name: url.lastPathComponent, path: url.path, mime: mime))
            }
        }
    }

    private func appendCameraAttachment(_ image: UIImage, to appState: AppState) {
        let url = FileManager.default.temporaryDirectory.appending(path: "hermes-photo-\(UUID().uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.86) {
            try? data.write(to: url)
        }
        withAnimation(easeOut) {
            appState.chat.stagedAttachments.append(AttachmentDTO(name: url.lastPathComponent, path: url.path, mime: "image/jpeg"))
        }
    }

    private func appendPhotoAttachment(_ item: PhotosPickerItem, to appState: AppState) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let contentType = item.supportedContentTypes.first
        let ext = contentType?.preferredFilenameExtension ?? "jpg"
        let mime = contentType?.preferredMIMEType ?? "image/jpeg"
        let url = FileManager.default.temporaryDirectory.appending(path: "hermes-library-\(UUID().uuidString).\(ext)")
        try? data.write(to: url)
        await MainActor.run {
            withAnimation(easeOut) {
                appState.chat.stagedAttachments.append(AttachmentDTO(name: url.lastPathComponent, path: url.path, mime: mime))
            }
            photoPickerItem = nil
        }
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
