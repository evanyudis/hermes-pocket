import SwiftUI

struct MessageRowView: View {
    let message: MessageDTO
    let isStreaming: Bool
    let isAwaitingStart: Bool
    let previousRole: String?
    let activeToolCall: ActiveToolCall?
    let completedToolSteps: [ToolCallStep]

    private var isUser: Bool { message.role == "user" }
    private var hasText: Bool { !message.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var segments: [MessageSegment] { ToolResultParser.parse(message.displayText) }
    private var topSpacing: CGFloat {
        if !isUser && previousRole == "user" { return 10 }
        if isUser && previousRole == "assistant" { return 10 }
        return 4
    }

    var body: some View {
        // Hide empty assistant messages completely
        if !isUser && !hasText && completedToolSteps.isEmpty && activeToolCall == nil && !isStreaming && !isAwaitingStart {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: 0) {
                if isUser { Spacer(minLength: 28) }

                content
                    .frame(maxWidth: 336, alignment: isUser ? .trailing : .leading)
            }
            .padding(.top, topSpacing)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isUser {
            userContent
        } else if (isStreaming || isAwaitingStart) && !hasText {
            streamingContent
        } else if hasText || !completedToolSteps.isEmpty || activeToolCall != nil {
            assistantContent
        }
    }

    // MARK: - User message

    private var userContent: some View {
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
    }

    // MARK: - Streaming (no text yet)

    private var streamingContent: some View {
        Group {
            if let activeToolCall {
                LiveToolCallingView(toolCall: activeToolCall)
                    .padding(.vertical, 4)
            } else {
                StreamingDotsView()
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Assistant message with text

    private var hasToolResults: Bool {
        segments.contains { segment in
            if case .toolResult(let data) = segment,
               case .webSearch = data { return true }
            return false
        }
    }

    private var assistantContent: some View {
        let hasVisibleContent = !segments.isEmpty || activeToolCall != nil || !completedToolSteps.isEmpty

        return VStack(alignment: .leading, spacing: 0) {
            if hasVisibleContent {
                // Use MarkdownUI for formatted rendering when no tool result tags present
                if hasToolResults {
                    toolResultSegmentView
                } else if hasText {
                    ChatMarkdownWithLatexView(
                        markdown: message.displayText,
                        isStreaming: isStreaming
                    )
                }

                // Live tool call indicator (during streaming)
                if let activeToolCall {
                    LiveToolCallingView(toolCall: activeToolCall)
                        .padding(.top, 6)
                }

                // Chain of thought summary (after stream ends)
                if !completedToolSteps.isEmpty {
                    ChainOfThoughtView(steps: completedToolSteps, messageID: message.id)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Tool result segment view (fallback)

    private var toolResultSegmentView: some View {
        let visibleSegments = segments.filter { segment in
            switch segment {
            case .text(let t):
                return !Self.stripToolMarkup(t).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .toolResult(let data):
                if case .unknown = data { return false }
                return true
            }
        }
        let hasLeadingText = visibleSegments.first.map { segment in
            if case .text = segment { return true }
            return false
        } ?? false

        return ForEach(Array(visibleSegments.enumerated()), id: \.offset) { index, segment in
            switch segment {
            case .text(let t):
                messageText(Self.stripToolMarkup(t).trimmingCharacters(in: .whitespacesAndNewlines))
            case .toolResult(let data):
                ToolResultCardView(data: data)
                    .padding(.top, index == 0 && !hasLeadingText ? 0 : 4)
            }
        }
    }

    // MARK: - Tool markup stripper

    /// Strips <untrusted_tool_call> and incomplete <untrusted_tool_result> blocks
    /// from text segments. Safety net for the mixed-content path where
    /// ChatMarkdownView's strippers aren't active.
    private static func stripToolMarkup(_ text: String) -> String {
        var result = text
        // Strip <untrusted_tool_call> blocks (complete or incomplete)
        let callPattern = "<untrusted_tool_call[^>]*>[\\s\\S]*?(?:</untrusted_tool_call>|$)"
        if let regex = try? NSRegularExpression(pattern: callPattern) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        // Strip incomplete <untrusted_tool_result> blocks (no closing tag yet during streaming)
        // Complete blocks are already parsed by ToolResultParser, but incomplete ones
        // leak as text and may contain raw JSON.
        let incompleteResultPattern = "<untrusted_tool_result[^>]*>[\\s\\S]*?(?:</untrusted_tool_result>|$)"
        if let regex = try? NSRegularExpression(pattern: incompleteResultPattern) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result
    }

    // MARK: - Text renderer (plain text fallback)

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
