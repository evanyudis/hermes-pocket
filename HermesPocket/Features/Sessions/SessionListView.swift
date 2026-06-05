import SwiftUI

struct SessionListView: View {
    @Environment(AppState.self) private var appState

    private let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.3)

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.045, blue: 0.055).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        newChatRow(isActive: appState.isNewChatQueued)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recents")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.gray)
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .padding(.horizontal, 4)

                            if appState.sessions.isLoading && appState.sessions.items.isEmpty {
                                ProgressView("Loading sessions...")
                                    .tint(.white)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.vertical, 12)
                            } else if appState.sessions.items.isEmpty {
                                Text("No sessions yet")
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(appState.sessions.items) { session in
                                    SessionRowView(session: session) {
                                        dismissKeyboard()
                                        Task {
                                            await appState.loadSession(sessionID: session.sessionId)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                bottomBar
            }
            .padding(.top, 50)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if appState.sessions.items.isEmpty {
                await appState.refreshSessions()
            }
        }
        .refreshable {
            await appState.refreshSessions()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Hermes Pocket")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Button {
                dismissKeyboard()
                withAnimation(easeOut) {
                    appState.route = .chat
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func newChatRow(isActive: Bool) -> some View {
        Button {
            dismissKeyboard()
            appState.startNewChatQueue()
            withAnimation(easeOut) {
                appState.route = .chat
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.and.pencil")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 24)

                Text("New Chat")
                    .font(.body)
                    .foregroundStyle(.white)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color(red: 0.18, green: 0.18, blue: 0.20) : Color(red: 0.12, green: 0.12, blue: 0.14))
                    .padding(.leading, -12)
                    .padding(.trailing, -12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(isActive ? 0.08 : 0.04), lineWidth: 1)
                    .padding(.leading, -12)
                    .padding(.trailing, -12)
            )
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text(appState.connection.baseURLString.isEmpty ? "No server" : appState.connection.baseURLString)
                .font(.caption)
                .foregroundStyle(.gray)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                appState.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

}
