import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Server") {
                Text(appState.connection.baseURLString.isEmpty ? "Not configured" : appState.connection.baseURLString)
            }

            Section("Default Model") {
                if appState.availableModels.isEmpty {
                    if appState.isFetchingModels {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
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

            Section("Debug") {
                Toggle("Stream Debug Logging", isOn: $appState.isStreamDebugLoggingEnabled)
                Text("Logs SSE lifecycle events like token, done, cancel, and stream_end to the console.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let error = appState.auth.lastError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section("Session") {
                Button("Back to Sessions") {
                    appState.showSessions()
                }

                Button("Log Out", role: .destructive) {
                    Task {
                        await appState.logout()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: appState.defaultModel) { _, newValue in
            appState.credentialStore.saveDefaultModel(newValue)
        }
        .onChange(of: appState.isStreamDebugLoggingEnabled) { _, newValue in
            appState.credentialStore.saveStreamDebugLoggingEnabled(newValue)
        }
        .task {
            if appState.availableModels.isEmpty && !appState.isFetchingModels {
                await appState.fetchModels()
            }
        }
    }
}
