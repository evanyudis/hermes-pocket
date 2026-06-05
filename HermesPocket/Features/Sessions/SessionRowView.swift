import SwiftUI

struct SessionRowView: View {
    @Environment(AppState.self) private var appState

    let session: SessionSummaryDTO
    let onOpen: () -> Void

    @State private var showRenameSheet = false
    @State private var renameDraft = ""

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(session.title)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer()

                if session.activeStreamId != nil {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .background(alignment: .leading) {
                if session.sessionId == appState.currentSessionID {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                        .padding(.leading, -12)
                        .padding(.trailing, -12)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                beginRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                Task {
                    await appState.archiveSession(sessionID: session.sessionId)
                }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            Button(role: .destructive) {
                Task {
                    await appState.deleteSession(sessionID: session.sessionId)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
    }

    private func beginRename() {
        renameDraft = session.title
        showRenameSheet = true
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
                        let title = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            await appState.renameSession(sessionID: session.sessionId, title: title)
                            showRenameSheet = false
                        }
                    }
                    .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
