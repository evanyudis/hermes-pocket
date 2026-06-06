import SwiftUI

struct ConnectionSetupView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Backend") {
                TextField("https://your-hermes.example.com", text: $appState.connection.baseURLString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }

            if let error = appState.connection.lastError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(appState.connection.isLoading ? "Connecting..." : "Continue") {
                    Task {
                        await appState.connect()
                    }
                }
                .disabled(appState.connection.baseURL == nil || appState.connection.isLoading)
            }
        }
        .navigationTitle("Hermes Pocket")
    }
}
