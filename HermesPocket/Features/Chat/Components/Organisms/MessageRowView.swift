import SwiftUI

struct MessageRowView: View {
    let message: MessageDTO
    let isStreaming: Bool
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
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
        } else if isStreaming && !hasText {
            StreamingDotsView()
                .padding(.vertical, 10)
        } else {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                messageText(message.displayText.isEmpty ? "Thinking..." : message.displayText)

                if isStreaming {
                    StreamingCursorView()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func messageText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 21, weight: .regular))
            .foregroundStyle(.primary)
            .lineSpacing(6)
            .tracking(-0.2)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
    }
}
