import SwiftUI

/// The greeting shown when the chat has no messages yet.
struct ChatEmptyView: View {
    let isKeyboardVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)

            Text(greetingText)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 40)

            if !isKeyboardVisible {
                subtitle
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()
        }
        .animation(.easeOut(duration: 0.3), value: isKeyboardVisible)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var subtitle: some View {
        Text("Start a conversation by typing below")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }
}
