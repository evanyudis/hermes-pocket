import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var appState
    @State private var showSidebar = false

    private let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.3)

    var body: some View {
        ZStack {
            NavigationStack {
                switch appState.route {
                case .connection:
                    ConnectionSetupView()
                case .login:
                    LoginView()
                case .sessions:
                    SessionListView()
                case .chat:
                    ChatView(
                        sessionID: appState.currentSessionID,
                        showSidebar: $showSidebar
                    )
                case .settings:
                    SettingsView()
                }
            }

            // Dim overlay — always rendered, fades in/out
            if appState.route == .chat {
                Color.black
                    .opacity(showSidebar ? 0.5 : 0)
                    .ignoresSafeArea()
                    .animation(easeOut, value: showSidebar)
                    .allowsHitTesting(showSidebar)
                    .onTapGesture {
                        dismissKeyboard()
                        withAnimation(easeOut) { showSidebar = false }
                    }
                    .zIndex(99)
            }

            // Sidebar
            if appState.route == .chat {
                ChatSidebarView(
                    showSidebar: $showSidebar
                )
                .zIndex(100)
            }
        }
        .task {
            await appState.bootstrapIfNeeded()
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
