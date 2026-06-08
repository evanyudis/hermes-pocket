import SwiftUI
import MarkdownUI
import LaTeXSwiftUI

/// Wraps `ChatMarkdownView` with display-math (`$$...$$`) rendering.
///
/// Extracts `$$...$$` display math blocks from markdown and renders them
/// as centered LaTeX cards via `LaTeXSwiftUI`. The surrounding markdown text
/// always renders through `ChatMarkdownView` (full MarkdownUI feature set).
///
/// Inline math (`$...$`) is NOT extracted — it passes through to MarkdownUI
/// as literal text. Full inline math support requires view-level splicing,
/// which is a deeper integration problem.
///
/// Streaming: extraction only runs on the final (non-streaming) text.
struct ChatMarkdownWithLatexView: View {
    let markdown: String
    let isStreaming: Bool

    private var segments: [Segment] {
        guard !isStreaming else { return [.markdown(markdown)] }
        return Self.parseSegments(markdown)
    }

    var body: some View {
        if isStreaming {
            ChatMarkdownView(markdown: markdown, isStreaming: true)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(segments.indices, id: \.self) { index in
                    switch segments[index] {
                    case .markdown(let text):
                        ChatMarkdownView(markdown: text, isStreaming: false)
                    case .latex(let equation):
                        displayMathBlock(equation)
                    }
                }
            }
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func displayMathBlock(_ equation: String) -> some View {
        LaTeX(equation)
            .parsingMode(.all)
            .blockMode(.blockViews)
            .font(.system(size: 18))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
            .markdownMargin(top: 6, bottom: 10)
            .textSelection(.enabled)
    }

    // MARK: - Segment parsing

    enum Segment {
        case markdown(String)
        case latex(String)
    }

    /// Splits text into alternating markdown and display-math segments.
    /// Only extracts `$$...$$`, `\[...\]`, and `\begin{equation}...`
    /// Inline `$...$` stays in markdown.
    static func parseSegments(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var remaining = text

        while !remaining.isEmpty {
            if let (range, eq) = findNextLatex(in: remaining) {
                let before = String(remaining[..<range.lowerBound])
                if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.markdown(before))
                }
                segments.append(.latex(eq))
                remaining = String(remaining[range.upperBound...])
            } else {
                if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.markdown(remaining))
                }
                break
            }
        }

        return segments
    }

    /// Finds the next display-math LaTeX block.
    /// Skips inline `$...$` since those are kept in markdown.
    private static func findNextLatex(in text: String) -> (Range<String.Index>, String)? {
        // Only match display-math delimiters (multi-line blocks).
        // Inline math ($...$, \(...\)) stays in markdown.
        let delimiters: [(String, String)] = [
            ("$$", "$$"),
            ("\\[", "\\]"),
            ("\\begin{equation}", "\\end{equation}"),
            ("\\begin{equation*}", "\\end{equation*}"),
        ]

        var earliest: (Range<String.Index>, String)? = nil

        for (open, close) in delimiters {
            guard let start = text.range(of: open) else { continue }

            let searchStart = text[text.index(start.lowerBound, offsetBy: open.count)...]

            guard let end = searchStart.range(of: close) else { continue }

            let content = String(searchStart[..<end.lowerBound])
            let fullRange = start.lowerBound..<end.upperBound

            if let (earliestRange, _) = earliest {
                if fullRange.lowerBound < earliestRange.lowerBound {
                    earliest = (fullRange, content)
                }
            } else {
                earliest = (fullRange, content)
            }
        }

        return earliest
    }
}
