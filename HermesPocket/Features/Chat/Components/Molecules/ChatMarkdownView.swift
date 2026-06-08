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
                    .markdownImageProvider(.hermes)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(imagePopup)
        .onChange(of: markdown) { _, newValue in
            if isStreaming {
                throttleRender(text: newValue)
            } else {
                renderedText = processed(newValue, isStreaming: false)
            }
        }
        // When streaming finishes, re-process the final text with full normalization
        // and theme. During streaming, markdown may not change after isStreaming flips
        // (last token already appended), so onChange(of: markdown) wouldn't fire.
        .onChange(of: isStreaming) { _, streaming in
            if !streaming {
                renderedText = processed(markdown, isStreaming: false)
            }
        }
        .onAppear {
            renderedText = processed(markdown, isStreaming: isStreaming)
        }
    }

    // MARK: - Throttled render

    /// Only re-renders the markdown body at most once per `streamThrottle` interval
    /// while streaming. This prevents SwiftUI + MarkdownUI from stuttering on every
    /// incoming token (which can arrive 20-50 times per second).
    /// During streaming we skip paragraph normalization to avoid corrupting
    /// partial markdown (e.g. unclosed code fences).
    private func throttleRender(text: String) {
        let now = Date()
        guard now.timeIntervalSince(lastRenderTime) >= streamThrottle else { return }
        lastRenderTime = now
        renderedText = processed(text, isStreaming: true)
    }

    /// Prepares markdown text for rendering.
    /// - Normalizes line endings
    /// - Strips tool result tags to prevent raw JSON from leaking into markdown
    /// - During streaming: skip paragraph normalization (would corrupt partial
    ///   markdown like unclosed code fences). Only normalize on final text.
    private func processed(_ src: String, isStreaming: Bool) -> String {
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

        // Paragraph normalization disabled — it inserts blank lines between
        // table rows, list items, and other markdown structures that require
        // contiguous lines, breaking their rendering.
        // TODO: Revisit with a smarter approach that respects markdown context.
        // if !isStreaming {
        //     t = Self.normalizeParagraphBreaks(t)
        // }

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

    // MARK: - Paragraph break normalization

    /// Normalizes single newlines to double newlines for proper Markdown paragraph
    /// breaks, while preserving fenced code blocks.
    ///
    /// AI models often return paragraphs separated by a single `\n` instead of
    /// the `\n\n` that Markdown requires for paragraph breaks. Without this
    /// normalization, all text renders as one continuous paragraph.
    ///
    /// - Preserves ``` and ~~~ fenced code blocks (internal newlines untouched)
    /// - Collapses 3+ consecutive newlines down to 2
    private static func normalizeParagraphBreaks(_ text: String) -> String {
        // Step 1: Extract and protect fenced code blocks
        let fencePattern = try! NSRegularExpression(pattern: "(```[\\s\\S]*?```|~~~[\\s\\S]*?~~~)")
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        let fenceMatches = fencePattern.matches(in: text, range: fullRange)

        var blocks: [String] = []
        var result = text
        var offset = 0

        for match in fenceMatches {
            let adj = NSRange(location: match.range.location - offset, length: match.range.length)
            let ns = result as NSString
            let block = ns.substring(with: adj)
            blocks.append(block)
            let placeholder = "\n\n\u{00}BLOCK\(blocks.count - 1)\u{00}\n\n"
            result = ns.replacingCharacters(in: adj, with: placeholder)
            offset += match.range.length - placeholder.count
        }

        // Step 2: Normalize single \n (not part of \n\n) to \n\n
        result = result.replacingOccurrences(
            of: "(?<!\n)\n(?!\n)",
            with: "\n\n",
            options: .regularExpression
        )

        // Step 3: Collapse 3+ consecutive newlines to 2
        result = result.replacingOccurrences(
            of: "\n\n\n+",
            with: "\n\n",
            options: .regularExpression
        )

        // Step 4: Restore code blocks
        for (i, block) in blocks.enumerated() {
            result = result.replacingOccurrences(
                of: "\n\n\u{00}BLOCK\(i)\u{00}\n\n",
                with: block
            )
        }

        return result
    }

    // MARK: - Image popup

    /// Full-screen image popup triggered by tapping an image in the markdown.
    @ViewBuilder
    private var imagePopup: some View {
        if ImagePopupState.shared.isPresented, let image = ImagePopupState.shared.selectedImage {
            Color.clear
                .overlay(
                    ImagePopupView(
                        image: image,
                        isPresented: Binding(
                            get: { ImagePopupState.shared.isPresented },
                            set: { ImagePopupState.shared.isPresented = $0 }
                        )
                    )
                )
                .transition(.opacity.animation(.easeOut(duration: 0.2)))
                .ignoresSafeArea()
                .zIndex(100)
        }
    }
}

// MARK: - Code Block

private struct CodeBlockView: View {
    let configuration: CodeBlockConfiguration
    @State private var didCopy = false

    private var isMermaid: Bool {
        let lang = configuration.language?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lang == "mermaid"
    }

    private var title: String {
        if let lang = configuration.language?.trimmingCharacters(in: .whitespacesAndNewlines), !lang.isEmpty {
            return lang.uppercased()
        }
        return "CODE"
    }

    var body: some View {
        if isMermaid {
            mermaidView
        } else {
            codeView
        }
    }

    // ── Mermaid diagram ──

    private var mermaidView: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 10, weight: .semibold))
                    Text(title)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.45))

                Spacer()

                copyButton
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.06))

            // Diagram
            MermaidDiagramView(source: configuration.content)
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        .markdownMargin(top: 14, bottom: 20)
    }

    // ── Regular code block ──

    private var codeView: some View {
        VStack(spacing: 0) {
            // Header bar: language label + copy button
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(title)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.45))

                Spacer()

                copyButton
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.06))

            // Scrollable code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(configuration.content.isEmpty ? " " : configuration.content)
                    .font(.system(size: 13.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                    .textSelection(.enabled)
                    .padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    // ── Shared copy button ──

    @ViewBuilder
    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = configuration.content
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 18)) {
                didCopy = true
            }
            Task { try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 18)) {
                    didCopy = false
                }
            }
        } label: {
            ZStack {
                Image(systemName: "doc.on.doc")
                    .opacity(didCopy ? 0 : 1)
                    .scaleEffect(didCopy ? 0.5 : 1)
                Image(systemName: "checkmark.circle.fill")
                    .opacity(didCopy ? 1 : 0)
                    .scaleEffect(didCopy ? 1 : 0.5)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(didCopy ? .green : .white.opacity(0.45))
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme

extension Theme {
    /// Hermes dark-theme for MarkdownUI.
    ///
    /// Based on the original working theme. Only safe additions:
    /// - strikethrough support
    /// - inline code color
    /// - paragraph readability tweaks
    /// Keeps all block styles (table, blockquote, list, codeBlock) at their
    /// defaults to avoid cascading rendering failures.
    @MainActor static let hermes = Theme()
        // ── Body text ──
        .text {
            FontSize(18)
            ForegroundColor(.primary)
        }
        // ── Inline code ──
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            ForegroundColor(.orange.opacity(0.9))
            BackgroundColor(.white.opacity(0.10))
        }
        // ── Bold / italic / strikethrough / links ──
        .strong { FontWeight(.semibold) }
        .strikethrough { StrikethroughStyle(.single) }
        .link {
            ForegroundColor(.blue)
            UnderlineStyle(.single)
        }

        // ── Headings ──
        .heading1 { c in
            c.label
                .markdownMargin(top: 22, bottom: 18)
                .markdownTextStyle { FontWeight(.bold); FontSize(.em(1.55)) }
        }
        .heading2 { c in
            c.label
                .markdownMargin(top: 18, bottom: 17)
                .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.35)) }
        }
        .heading3 { c in
            c.label
                .markdownMargin(top: 16, bottom: 16)
                .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.15)) }
        }

        // ── Paragraphs ──
        .paragraph { c in
            c.label
                .markdownMargin(top: 0, bottom: 14)
                .relativeLineSpacing(.em(0.36))
        }

        // ── Blockquotes ──
        .blockquote { c in
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.25))
                    .frame(width: 3)
                c.label
                    .padding(.leading, 10)
                    .markdownTextStyle {
                        BackgroundColor(.clear)
                        ForegroundColor(.white.opacity(0.72))
                    }
            }
            .fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: 12, bottom: 12)
        }

        // ── Images ──
        .image { c in
            c.label
                .frame(maxWidth: .infinity)
                .markdownMargin(top: 12, bottom: 18)
        }

        // ── Code blocks ──
        .codeBlock { configuration in
            CodeBlockView(configuration: configuration)
        }

        // ── Lists ──
        .listItem { c in
            c.label.markdownMargin(top: .em(0.12), bottom: .em(0.12))
        }
        .taskListMarker { c in
            Image(systemName: c.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(c.isCompleted ? .blue : .white.opacity(0.3))
                .font(.system(size: 20))
        }

        // ── Tables ──
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

        // ── Thematic break ──
        .thematicBreak {
            Divider()
                .overlay(.white.opacity(0.12))
                .markdownMargin(top: 14, bottom: 14)
        }
}
