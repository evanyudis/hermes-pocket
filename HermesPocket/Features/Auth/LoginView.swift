import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var password = ""

    var body: some View {
        Form {
            Section("Connection") {
                Text(appState.connection.baseURLString.isEmpty ? "No server selected" : appState.connection.baseURLString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Password") {
                SecureField("Password", text: $password)
            }

            if let error = appState.auth.lastError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(appState.auth.isLoading ? "Signing In..." : "Sign In") {
                    Task {
                        await appState.login(password: password)
                    }
                }
                .disabled(password.isEmpty || appState.auth.isLoading)
            }
        }
        .navigationTitle("Sign In")
    }
}
