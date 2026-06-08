import SwiftUI
import MarkdownUI

/// Minimum interval (seconds) between markdown re-renders during streaming.
/// Prevents SwiftUI + MarkdownUI from stuttering on every token.
private let streamThrottle: TimeInterval = 0.12

struct ChatMarkdownView: View {
    let markdown: String
    let isStreaming: Bool

    @State private var renderedText: String = ""
    @State private var lastRenderTime: Date = .distantPast

    var body: some View {
        Group {
            if renderedText.isEmpty {
                Text("_ _").foregroundStyle(.white.opacity(0.4))
            } else {
                Markdown(renderedText)
                    .markdownTheme(.hermes)
                    .markdownBlockStyle(\.codeBlock) { config in
                        CodeBlockView(configuration: config)
                    }
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: markdown) { _, newValue in
            if isStreaming {
                throttleRender(text: newValue)
            } else {
                renderedText = processed(newValue)
            }
        }
        .onAppear {
            renderedText = processed(markdown)
        }
    }

    // MARK: - Throttled render

    /// Only re-renders the markdown body at most once per `streamThrottle` interval
    /// while streaming. This prevents SwiftUI + MarkdownUI from stuttering on every
    /// incoming token (which can arrive 20-50 times per second).
    private func throttleRender(text: String) {
        let now = Date()
        guard now.timeIntervalSince(lastRenderTime) >= streamThrottle else { return }
        lastRenderTime = now
        renderedText = processed(text)
    }

    /// Prepares markdown text for rendering.
    /// - Normalizes line endings
    /// - Strips tool result tags to prevent raw JSON from leaking into markdown
    ///   (happens when ToolResultParser didn't extract them, e.g. unknown source)
    private func processed(_ src: String) -> String {
        var t = src
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Always strip untrusted_tool_result blocks — they should be rendered
        // as cards via toolResultSegmentView, not as raw text in markdown.
        // During streaming the tags may be incomplete; even when complete,
        // unknown-source tool results leak through since hasToolResults only
        // checks for .webSearch.
        t = Self.stripToolResultTags(t)

        // Strip untrusted_tool_call blocks — they are shown via the live
        // tool calling UI (LiveToolCallingView), not as raw markdown.
        t = Self.stripToolCallTags(t)

        return t
    }

    /// Removes <untrusted_tool_result> blocks (complete or incomplete) from text.
    /// Prevents raw JSON like {"total_count":0} from showing as plain text.
    private static func stripToolResultTags(_ text: String) -> String {
        let pattern = "<untrusted_tool_result[^>]*>[\\s\\S]*?(?:</untrusted_tool_result>|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    /// Removes <untrusted_tool_call> blocks (complete or incomplete) from text.
    /// Tool calls are rendered via LiveToolCallingView, not as raw markdown.
    private static func stripToolCallTags(_ text: String) -> String {
        let pattern = "<untrusted_tool_call[^>]*>[\\s\\S]*?(?:</untrusted_tool_call>|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
}

// MARK: - Code Block

private struct CodeBlockView: View {
    let configuration: CodeBlockConfiguration
    @State private var didCopy = false

    private var title: String {
        if let lang = configuration.language?.trimmingCharacters(in: .whitespacesAndNewlines), !lang.isEmpty {
            return lang.uppercased()
        }
        return "CODE"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Button {
                    UIPasteboard.general.string = configuration.content
                    withAnimation(.easeInOut(duration: 0.16)) { didCopy = true }
                    Task { try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(.easeInOut(duration: 0.16)) { didCopy = false } }
                } label: {
                    ZStack {
                        Image(systemName: "doc.on.doc").opacity(didCopy ? 0 : 1)
                        Image(systemName: "checkmark").opacity(didCopy ? 1 : 0)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(didCopy ? .blue : .white.opacity(0.4))
                    .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.white.opacity(0.06))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(configuration.content.isEmpty ? " " : configuration.content)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Theme

extension Theme {
    @MainActor static let hermes = Theme()
        .text { FontSize(18); ForegroundColor(.primary) }
        .code { FontFamilyVariant(.monospaced); FontSize(.em(0.88)); BackgroundColor(.white.opacity(0.10)) }
        .strong { FontWeight(.semibold) }
        .link { ForegroundColor(.blue); UnderlineStyle(.single) }

        .heading1 { c in c.label.markdownMargin(top: 22, bottom: 18).markdownTextStyle { FontWeight(.bold); FontSize(.em(1.55)) } }
        .heading2 { c in c.label.markdownMargin(top: 18, bottom: 17).markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.35)) } }
        .heading3 { c in c.label.markdownMargin(top: 16, bottom: 16).markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.15)) } }

        .paragraph { c in c.label.markdownMargin(top: 0, bottom: 14).relativeLineSpacing(.em(0.33)) }

        .blockquote { c in
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.25)).frame(width: 3)
                c.label.padding(.leading, 10).markdownTextStyle { BackgroundColor(.clear); ForegroundColor(.white.opacity(0.72)) }
            }
            .fixedSize(horizontal: false, vertical: true).markdownMargin(top: 12, bottom: 12)
        }

        .codeBlock { c in c.label.markdownMargin(top: 14, bottom: 18) }

        .listItem { c in c.label.markdownMargin(top: .em(0.12), bottom: .em(0.12)) }
        .taskListMarker { c in
            Image(systemName: c.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(c.isCompleted ? .blue : .white.opacity(0.3))
                .font(.system(size: 20))
        }

        .table { c in
            ViewThatFits(in: .horizontal) {
                c.label.fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: .white.opacity(0.10)))
                    .markdownTableBackgroundStyle(.alternatingRows(.white.opacity(0.04), .white.opacity(0.08)))
                ScrollView(.horizontal, showsIndicators: false) {
                    c.label.fixedSize(horizontal: false, vertical: true)
                        .markdownTableBorderStyle(.init(color: .white.opacity(0.10)))
                        .markdownTableBackgroundStyle(.alternatingRows(.white.opacity(0.04), .white.opacity(0.08)))
                }
            }
            .markdownMargin(top: 18, bottom: 22)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .tableCell { c in
            c.label.markdownTextStyle {
                if c.row == 0 { FontWeight(.semibold); BackgroundColor(.white.opacity(0.06)) }
                else { BackgroundColor(.clear) }
            }
            .padding(.vertical, 10).padding(.horizontal, 14).relativeLineSpacing(.em(0.22))
        }

        .thematicBreak { Divider().overlay(.white.opacity(0.12)).markdownMargin(top: 14, bottom: 14) }
}
