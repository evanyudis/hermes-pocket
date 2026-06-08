import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @State private var baseURLString = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showHow = false

    private let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
    private let easeOutFast = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
    @State private var isPressingConnect = false

    @State private var isKeyboardActive = false
    @State private var breathing = false

    @FocusState private var focusedField: FieldType?
    private enum FieldType: Hashable {
        case url
        case password
    }

    var body: some View {
        GeometryReader { geometry in
            let spacerHeight = isKeyboardActive ? 8 : geometry.size.height * 0.55
            let visualizationOpacity = isKeyboardActive ? 0.0 : 1.0
            let visualizationOffset: CGFloat = isKeyboardActive ? -20 : 0

            ZStack {
                // MARK: - Full screen background
                backgroundGradient
                    .ignoresSafeArea()

                // MARK: - U-shaped breathing gradient
                breathingGradient
                    .ignoresSafeArea()

                // MARK: - Floating visualization
                VStack {
                    Spacer()
                        .frame(height: geometry.size.height * 0.1)

                    visualizationArea
                        .frame(maxHeight: geometry.size.height * 0.4)

                    Spacer()
                }
                .opacity(visualizationOpacity)
                .offset(y: visualizationOffset)

                // MARK: - Bottom card
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: spacerHeight)

                        cardContent
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
            }
            .onChange(of: focusedField) { _, newValue in
                let active = newValue != nil
                withAnimation(active ? easeOut : easeOutFast) {
                    isKeyboardActive = active
                }
            }
            .onAppear {
                baseURLString = appState.connection.baseURLString
                startBreathing()
            }
            .sheet(isPresented: $showHow) {
                howItWorksSheet
            }
        }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }

    // MARK: - Visualization Area

    private var visualizationArea: some View {
        VStack(spacing: 16) {
            Spacer()

            // App icon (Nous Research Hermes logo)
            ZStack {
                // Soft glow halo behind the logo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04),
                                .clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)

                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorInvert()
                    .frame(width: 140, height: 140)
                    .shadow(color: .white.opacity(0.1), radius: 12, y: 0)
            }

            // Tagline
            Text("Your AI companion,\nalways in your pocket")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Background Gradient

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black,
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Decorative mesh dots
            MeshDots()
                .opacity(0.08)
        }
    }

    // MARK: - U-Shaped Breathing Gradient

    private var breathingGradient: some View {
        ZStack {
            // Bottom-center core glow
            RadialGradient(
                colors: [
                    Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.45),
                    Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.18),
                    .clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 520
            )

            // Left arm of the U
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.50, blue: 1.0).opacity(0.35),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 360
            )

            // Right arm of the U
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.50, blue: 1.0).opacity(0.35),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 360
            )

            // Soft inner curl — gives the U a sense of curving upward
            LinearGradient(
                colors: [.clear, Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.08), .clear],
                startPoint: .bottom,
                endPoint: .center
            )
        }
        .opacity(breathing ? 1.0 : 0.55)
        .blendMode(.plusLighter)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Card background
            VStack(alignment: .leading, spacing: 24) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hermes Pocket")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Connect to your server")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Combined URL + Password fields (iOS Settings grouped style)
                VStack(spacing: 0) {
                    // URL field
                    HStack(spacing: 0) {
                        TextField("server.example.com", text: $baseURLString)
                            .font(.subheadline)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .url)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }

                    Divider()
                        .padding(.leading, 16)

                    // Password field
                    HStack(spacing: 0) {
                        SecureField("Password", text: $password)
                            .font(.subheadline)
                            .focused($focusedField, equals: .password)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.thinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                )

                // Error banner
                if let errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)

                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.orange.opacity(0.08))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Connect button
                Button {
                    isPressingConnect = true
                    Task {
                        await connect()
                        isPressingConnect = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.body)
                        }
                        Text(isLoading ? "Connecting..." : "Connect")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canConnect ? Color.accentColor : Color(.systemGray4))
                    )
                    .foregroundStyle(.white)
                    .scaleEffect(isPressingConnect ? 0.97 : 1)
                    .animation(easeOut, value: isPressingConnect)
                }
                .disabled(!canConnect || isLoading)

                // How it works link
                Button {
                    showHow = true
                } label: {
                    HStack(spacing: 4) {
                        Text("See how it works")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "questionmark.circle.fill")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.035), radius: 14, y: -2)
            .environment(\.colorScheme, .dark)
        }
    }

    // MARK: - Helpers

    private var canConnect: Bool {
        !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func connect() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        appState.connection.baseURLString = baseURLString
        appState.connection.lastError = nil
        appState.auth.lastError = nil

        let pw = password.trimmingCharacters(in: .whitespacesAndNewlines)

        await appState.connectAndLogin(password: pw)

        if let error = appState.connection.lastError ?? appState.auth.lastError {
            errorMessage = error
        }

        isLoading = false
    }

    // MARK: - How It Works Sheet

    private var howItWorksSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            stepRow(index: 1, title: "Run a Hermes server",
                                    detail: "You need a Hermes backend running on your machine or a remote server.")
                            stepRow(index: 2, title: "Enter the server URL",
                                    detail: "Paste your server's address (e.g., https://hermes.example.com).")
                            stepRow(index: 3, title: "Authenticate",
                                    detail: "If your server requires a password, enter it. Otherwise leave it blank.")
                            stepRow(index: 4, title: "Connect",
                                    detail: "Tap Connect and you'll be taken straight to your conversations.")
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Label("Setup Steps", systemImage: "list.number")
                            .font(.headline)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Link(destination: URL(string: "https://github.com/evanyudis/hermes")!) {
                                HStack {
                                    Label("Hermes on GitHub", systemImage: "book.closed")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(Color.accentColor)

                            Divider()

                            Link(destination: URL(string: "https://hermes.evanyudis.com")!) {
                                HStack {
                                    Label("Documentation", systemImage: "doc.text")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                    } label: {
                        Label("Resources", systemImage: "link")
                            .font(.headline)
                    }
                }
                .padding()
            }
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showHow = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func stepRow(index: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Decorative Mesh Background

private struct MeshDots: View {
    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 40
            ForEach(0..<Int(geometry.size.height / spacing), id: \.self) { row in
                ForEach(0..<Int(geometry.size.width / spacing), id: \.self) { col in
                    Circle()
                        .fill(.white)
                        .frame(width: 1.5, height: 1.5)
                        .position(
                            x: CGFloat(col) * spacing + spacing / 2,
                            y: CGFloat(row) * spacing + spacing / 2
                        )
                        .opacity(row % 2 == col % 2 ? 0.5 : 0.2)
                }
            }
        }
    }
}
