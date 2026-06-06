import SwiftUI
import PhotosUI

struct ChatComposerView: View {
    @Binding var draft: String
    @Binding var stagedAttachments: [AttachmentDTO]
    @Binding var photoPickerItem: PhotosPickerItem?
    let pendingClarify: ClarifyPendingDTO?
    let isStreaming: Bool
    let isLoading: Bool
    let availableModels: [ModelGroupDTO]
    let isFetchingModels: Bool
    let defaultModel: String
    let serverDefaultModel: String?
    let easeOut: Animation
    let onAttachmentMenuTapCamera: () -> Void
    let onAttachmentMenuTapPhotoLibrary: () -> Void
    let onAttachmentMenuTapFile: () -> Void
    let onSelectServerDefaultModel: () -> Void
    let onSelectModel: (_ providerID: String, _ modelID: String) -> Void
    let onSend: () -> Void
    let onStop: () -> Void
    let onFetchModels: () async -> Void
    let onHeightChange: (CGFloat) -> Void
    let focus: FocusState<Bool>.Binding

    private var hasDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isExpanded: Bool {
        hasDraft || !stagedAttachments.isEmpty
    }

    private var canSend: Bool {
        if isStreaming { return true }
        if isLoading { return false }
        if pendingClarify != nil { return false }
        return hasDraft || !stagedAttachments.isEmpty
    }

    private var selectedModelTitle: String {
        guard !defaultModel.isEmpty else { return serverDefaultModel ?? "Model" }
        return availableModels
            .flatMap { $0.models ?? [] }
            .first { $0.id == defaultModel }?
            .label ?? defaultModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !stagedAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(stagedAttachments, id: \.path) { attachment in
                            AttachmentCardView(attachment: attachment, style: .composer) {
                                withAnimation(easeOut) {
                                    stagedAttachments.removeAll { $0.path == attachment.path }
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .animation(easeOut, value: stagedAttachments.count)
                }
            }

            TextField(
                pendingClarify == nil ? "Send a message..." : "Respond above to continue",
                text: $draft,
                axis: .vertical
            )
            .font(.system(size: 18, weight: hasDraft ? .semibold : .regular))
            .foregroundStyle(.primary)
            .lineLimit(1...6)
            .disabled(pendingClarify != nil)
            .focused(focus)
            .submitLabel(.send)
            .onSubmit {
                guard canSend else { return }
                onSend()
            }

            HStack(alignment: .center, spacing: 12) {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button(action: onAttachmentMenuTapCamera) {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }

                    Button(action: onAttachmentMenuTapPhotoLibrary) {
                        Label("From Library", systemImage: "photo.on.rectangle")
                    }

                    Button(action: onAttachmentMenuTapFile) {
                        Label("Upload File", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)

                Menu {
                    Button(action: onSelectServerDefaultModel) {
                        Label("Use server default", systemImage: defaultModel.isEmpty ? "checkmark" : "circle")
                    }

                    ForEach(availableModels, id: \.providerId) { group in
                        Section(group.provider ?? group.providerId ?? "Models") {
                            ForEach(group.models ?? []) { entry in
                                Button {
                                    onSelectModel(group.providerId ?? group.provider ?? "", entry.id)
                                } label: {
                                    Label(entry.label ?? entry.id, systemImage: defaultModel == entry.id ? "checkmark" : "circle")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(selectedModelTitle)
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
                .menuStyle(.button)

                Spacer(minLength: 6)

                Button {
                    if isStreaming {
                        onStop()
                    } else {
                        onSend()
                    }
                } label: {
                    Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(canSend ? .white : .white.opacity(0.32))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(canSend ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(.ultraThinMaterial))
                                .environment(\.colorScheme, .dark)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, isExpanded ? 14 : 12)
        .padding(.bottom, 12)
        .liquidGlass(RoundedRectangle(cornerRadius: 24, style: .continuous), preset: .composer)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.top, 0)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        onHeightChange(proxy.size.height)
                    }
                    .onChange(of: proxy.size.height) { _, height in
                        onHeightChange(height)
                    }
            }
        )
        .animation(easeOut, value: isExpanded)
        .task {
            if availableModels.isEmpty && !isFetchingModels {
                await onFetchModels()
            }
        }
    }
}
