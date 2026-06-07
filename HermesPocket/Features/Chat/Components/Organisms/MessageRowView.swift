import SwiftUI

struct MessageRowView: View {
    let message: MessageDTO
    let isStreaming: Bool
    let isAwaitingStart: Bool
    let previousRole: String?

    private var isUser: Bool { message.role == "user" }
    private var hasText: Bool { !message.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var topSpacing: CGFloat {
        if !isUser && previousRole == "user" { return 18 }
        if isUser && previousRole == "assistant" { return 10 }
        return 4
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 28) }

            content
                .frame(maxWidth: 336, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 28) }
        }
        .padding(.top, topSpacing)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var content: some View {
        if isUser {
            VStack(alignment: .leading, spacing: 10) {
                if !message.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(message.attachments, id: \.path) { attachment in
                            AttachmentCardView(attachment: attachment, style: .message)
                        }
                    }
                }

                if hasText {
                    messageText(message.displayText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
        } else if (isStreaming || isAwaitingStart) && !hasText {
            StreamingDotsView()
                .padding(.vertical, 10)
                .frame(height: 28, alignment: .leading)
        } else if hasText {
            messageText(message.displayText)
        }
    }

    private func messageText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(.primary)
            .lineSpacing(6)
            .tracking(-0.2)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
    }
}
