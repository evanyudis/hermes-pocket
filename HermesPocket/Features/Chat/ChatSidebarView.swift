import SwiftUI

struct ChatSidebarView: View {
    @Environment(AppState.self) private var appState
    @Binding var showSidebar: Bool
    @State private var showSettings = false
    @State private var scrollContentHeight: CGFloat = 0

    private let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.3)

    private var canScroll: Bool {
        scrollContentHeight > 1
    }

    var body: some View {
        sidebarContent
            .frame(width: UIScreen.main.bounds.width)
            .background(Color(red: 0.045, green: 0.045, blue: 0.055))
            .offset(x: showSidebar ? 0 : -UIScreen.main.bounds.width)
            .scaleEffect(showSidebar ? 1 : 0.985, anchor: .leading)
            .opacity(showSidebar ? 1 : 0.98)
            .animation(easeOut, value: showSidebar)
            .allowsHitTesting(showSidebar)
            .sheet(isPresented: $showSettings) {
                sidebarSettingsSheet
            }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        newChatRow()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sessions")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.gray)

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
                                            withAnimation(easeOut) { showSidebar = false }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .background(
                        GeometryReader { contentProxy in
                            Color.clear
                                .preference(key: ScrollContentHeightKey.self, value: contentProxy.size.height)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollDisabled(!canScroll)
                .onPreferenceChange(ScrollContentHeightKey.self) { scrollContentHeight = $0 - proxy.size.height }
            }

            bottomBar
        }
        .safeAreaPadding(.top, 4)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Hermes Pocket")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            Button {
                dismissKeyboard()
                withAnimation(easeOut) { showSidebar = false }
            } label: {
                glassControlIcon(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 56)
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func newChatRow() -> some View {
        Button {
            dismissKeyboard()
            if !appState.isNewChatQueued {
                appState.startNewChatQueue()
            }
            withAnimation(easeOut) { showSidebar = false }
        } label: {
            HStack(alignment: .center, spacing: 12) {
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
            .background(alignment: .leading) {
                if appState.isNewChatQueued {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                        .padding(.leading, -12)
                        .padding(.trailing, -12)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text(appState.connection.baseURLString.isEmpty ? "No server" : appState.connection.baseURLString)
                .font(.callout)
                .foregroundStyle(.gray)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                dismissKeyboard()
                showSettings = true
            } label: {
                glassControlIcon(systemName: "gearshape")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func glassControlIcon(systemName: String) -> some View {
        GlassCircleButton(systemName: systemName)
            .environment(\.colorScheme, .dark)
            .foregroundStyle(.white)
    }

    private var sidebarSettingsSheet: some View {
        @Bindable var appState = appState
        return NavigationStack {
            Form {
                Section("Connection") {
                    Text(appState.connection.baseURLString.isEmpty ? "Not configured" : appState.connection.baseURLString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Reconfigure", role: .destructive) {
                        showSettings = false
                        showSidebar = false
                        Task {
                            await appState.logout()
                            appState.route = .connection
                        }
                    }
                }

                Section("Default Model") {
                    if appState.availableModels.isEmpty {
                        if appState.isFetchingModels {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Loading models...")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            TextField("Model", text: $appState.defaultModel)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    } else {
                        Picker("Model", selection: $appState.defaultModel) {
                            Text("Use server default").tag("")
                            ForEach(appState.availableModels, id: \.providerId) { group in
                                Section(group.provider ?? group.providerId ?? "Models") {
                                    ForEach(group.models ?? []) { entry in
                                        Text(entry.label ?? entry.id).tag(entry.id)
                                    }
                                }
                            }
                        }

                        if !appState.defaultModel.isEmpty {
                            let allIds = Set(appState.availableModels.flatMap { $0.models ?? [] }.map(\.id))
                            if !allIds.contains(appState.defaultModel) {
                                TextField("Custom model", text: $appState.defaultModel)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                }
            }
            .onChange(of: appState.defaultModel) { _, nv in
                appState.credentialStore.saveDefaultModel(nv)
            }
            .task {
                if appState.availableModels.isEmpty && !appState.isFetchingModels {
                    await appState.fetchModels()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

}

private struct ScrollContentHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
