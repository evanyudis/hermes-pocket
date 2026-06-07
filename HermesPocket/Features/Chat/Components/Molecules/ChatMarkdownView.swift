import SwiftUI
import MarkdownUI
import LaTeXSwiftUI
import WebKit

struct ChatMarkdownView: View {
    let markdown: String
    let isStreaming: Bool

    var body: some View {
        let src = normalize(markdown)
        Markdown(src.nilIfEmpty ?? "_ _")
            .markdownTheme(.hermes)
            .markdownBlockStyle(\.codeBlock) { config in
                HermesCodeBlockView(configuration: config)
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Ensure blank lines around code fences so MarkdownUI detects them
    private func normalize(_ src: String) -> String {
        var t = src.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if let r = try? NSRegularExpression(pattern: "(?m)(\\S)(\\n```)") {
            t = r.stringByReplacingMatches(in: t, range: NSRange(location: 0, length: t.utf16.count), withTemplate: "$1\n\n$2")
        }
        return t
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Code Block

private struct HermesCodeBlockView: View {
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

            Text(configuration.content.isEmpty ? " " : configuration.content)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Theme

extension Theme {
    @MainActor static let hermes = Theme()
        // ── base ──
        .text {
            FontSize(18)
            ForegroundColor(.primary)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            BackgroundColor(.white.opacity(0.10))
        }
        .strong { FontWeight(.semibold) }
        .link { ForegroundColor(.blue); UnderlineStyle(.single) }

        // ── headings ──
        .heading1 { c in c.label.markdownMargin(top: 22, bottom: 18)
            .markdownTextStyle { FontWeight(.bold); FontSize(.em(1.55)) } }
        .heading2 { c in c.label.markdownMargin(top: 18, bottom: 17)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.35)) } }
        .heading3 { c in c.label.markdownMargin(top: 16, bottom: 16)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.15)) } }

        // ── paragraph ──
        .paragraph { c in c.label.markdownMargin(top: 0, bottom: 14).relativeLineSpacing(.em(0.33)) }

        // ── blockquote ──
        .blockquote { c in
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.25)).frame(width: 3)
                c.label.padding(.leading, 10).markdownTextStyle {
                    BackgroundColor(.clear); ForegroundColor(.white.opacity(0.72))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: 12, bottom: 12)
        }

        // ── lists ──
        .listItem { c in c.label.markdownMargin(top: .em(0.12), bottom: .em(0.12)) }
        .taskListMarker { c in
            Image(systemName: c.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(c.isCompleted ? .blue : .white.opacity(0.3))
                .font(.system(size: 20))
        }

        // ── code block fallback (overridden above) ──
        .codeBlock { c in c.label.markdownMargin(top: 14, bottom: 18) }

        // ── table ──
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

        // ── divider ──
        .thematicBreak { Divider().overlay(.white.opacity(0.12)).markdownMargin(top: 14, bottom: 14) }
}
