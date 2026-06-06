import SwiftUI
import MarkdownUI
import LaTeXSwiftUI

struct ChatMarkdownView: View {
    let markdown: String
    let isStreaming: Bool

    var body: some View {
        MarkdownContent(markdown: markdown)
            .textSelection(.enabled)
    }
}

// MARK: - Markdown Content with Math Support

private struct MarkdownContent: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let segments = parseSegments(markdown)
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment.kind {
                case .markdown(let text):
                    Markdown(text)
                        .markdownTheme(.hermes)
                        .markdownBlockStyle(\.codeBlock) { config in
                            CodeBlockWithCopy(
                                code: config.content,
                                language: config.language
                            )
                        }
                case .latexBlock(let latex):
                    LaTeX(latex)
                        .blockMode(.blockViews)
                        .padding(.vertical, 8)
                case .latexInline(let latex):
                    LaTeX(latex)
                        .blockMode(.alwaysInline)
                }
            }
        }
    }
}

// MARK: - Segment Parser

private struct MarkdownSegment: Identifiable {
    enum Kind {
        case markdown(String)
        case latexBlock(String)
        case latexInline(String)
    }

    let id = UUID()
    let kind: Kind
}

/// Splits markdown into regular markdown segments and LaTeX math segments.
/// Handles `$$...$$` (display math) and `$...$` (inline math, only when surrounded by whitespace/punctuation).
private func parseSegments(_ text: String) -> [MarkdownSegment] {
    var segments: [MarkdownSegment] = []
    var remaining = text

    while !remaining.isEmpty {
        // Look for display math first
        if let range = remaining.firstRange(of: "$$") {
            let before = String(remaining[remaining.startIndex..<range.lowerBound])
            if !before.isEmpty {
                segments.append(MarkdownSegment(kind: .markdown(before)))
            }

            var afterFirst = remaining[range.upperBound...]
            if let closing = afterFirst.firstRange(of: "$$") {
                let latex = String(afterFirst[afterFirst.startIndex..<closing.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !latex.isEmpty {
                    segments.append(MarkdownSegment(kind: .latexBlock(latex)))
                }
                remaining = String(afterFirst[closing.upperBound...])
            } else {
                // No closing $$, treat as literal
                segments.append(MarkdownSegment(kind: .markdown("$$")))
                remaining = String(afterFirst)
            }
        } else if let range = remaining.firstRange(of: "$") {
            let before = String(remaining[remaining.startIndex..<range.lowerBound])
            if !before.isEmpty {
                segments.append(MarkdownSegment(kind: .markdown(before)))
            }

            var afterFirst = remaining[range.upperBound...]
            if let closing = afterFirst.firstRange(of: "$"),
               !afterFirst[afterFirst.startIndex..<closing.lowerBound].isEmpty {
                let latex = String(afterFirst[afterFirst.startIndex..<closing.lowerBound])
                // Only treat as inline math if it doesn't contain newlines
                if !latex.contains("\n") {
                    segments.append(MarkdownSegment(kind: .latexInline(latex.trimmingCharacters(in: .whitespaces))))
                    remaining = String(afterFirst[closing.upperBound...])
                } else {
                    segments.append(MarkdownSegment(kind: .markdown("$")))
                    remaining = String(afterFirst)
                }
            } else {
                segments.append(MarkdownSegment(kind: .markdown("$")))
                remaining = String(afterFirst)
            }
        } else {
            segments.append(MarkdownSegment(kind: .markdown(remaining)))
            remaining = ""
        }
    }

    return segments
}

// MARK: - Code Block with Copy Button

private struct CodeBlockWithCopy: View {
    let code: String
    let language: String?

    @State private var didCopy = false

    private var label: String {
        language?.isEmpty == false ? language! : "code"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(0.06)

                Spacer()

                Button {
                    UIPasteboard.general.string = code
                    withAnimation(.easeInOut(duration: 0.15)) {
                        didCopy = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.easeInOut(duration: 0.15)) {
                            didCopy = false
                        }
                    }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(didCopy ? .green : .white.opacity(0.45))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(didCopy ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

// MARK: - Hermes Theme

extension Theme {
    @MainActor static let hermes = Theme()
        .text {
            FontSize(18)
        }
        .heading1 { config in
            config.label
                .markdownTextStyle { FontWeight(.bold); FontSize(24) }
        }
        .heading2 { config in
            config.label
                .markdownTextStyle { FontWeight(.semibold); FontSize(21) }
        }
        .heading3 { config in
            config.label
                .markdownTextStyle { FontWeight(.semibold); FontSize(18) }
        }
}
