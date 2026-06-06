import SwiftUI

struct ChatHeaderView: View {
    let title: String
    let hasRealSession: Bool
    let sessionID: String?
    let showSidebar: Bool
    let onToggleSidebar: () -> Void
    let onRename: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSidebar) {
                GlassCircleButton(systemName: showSidebar ? "xmark" : "line.3.horizontal")
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasRealSession {
                Menu {
                    Section {
                        Button(action: onRename) {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(action: onArchive) {
                            Label("Archive", systemImage: "archivebox")
                        }

                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } header: {
                        Text(sessionID ?? "Session ID unavailable")
                            .font(.caption)
                    }
                } label: {
                    GlassCircleButton(systemName: "ellipsis")
                }
                .buttonStyle(.plain)
                .menuStyle(.button)
            }
        }
        .frame(minHeight: 56)
    }
}
