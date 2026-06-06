import SwiftUI
import MarkdownUI
import LaTeXSwiftUI
import WebKit

// MARK: - Design tokens (match existing chat UI)

private enum D {
    static let fontSize: CGFloat = 18
    static let lineSpacing: CGFloat = 6
    static let tracking: CGFloat = -0.2
    static let lineHeightEm: CGFloat = lineSpacing / fontSize  // 0.333em

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let surface = Color.white.opacity(0.06)
    static let accent = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let border = Color.white.opacity(0.10)
    static let inlineCodeBg = Color.white.opacity(0.12)
    static let quoteBar = Color.white.opacity(0.28)
}

// MARK: - Main View

struct ChatMarkdownView: View {
    let markdown: String
    let isStreaming: Bool

    private var normalized: String { normalizeMarkdown(markdown) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .markdown(let text):
                    Markdown(text)
                        .markdownTheme(.hermes)
                        .markdownBlockStyle(\.codeBlock) { config in
                            HermesCodeBlockView(configuration: config)
                        }
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .math(let text):
                    LaTeX(text)
                        .blockMode(.blockViews)
                        .errorMode(.original)
                        .font(.system(size: D.fontSize))
                        .foregroundStyle(D.textPrimary)
                        .textSelection(.enabled)
                        .padding(.vertical, 8)
                case .mermaid(let text):
                    MermaidDiagramView(source: text)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - Markdown normalization (ensure blank lines around blocks)

    private func normalizeMarkdown(_ src: String) -> String {
        var t = src.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Ensure blank line before block-level starts
        let patterns = [
            "(?m)(\\S)(#{1,6}\\s)",
            "(?m)(\\S)(\\n>\\s)",
            "(?m)(\\S)(\\n\\d+\\.\\s)",
            "(?m)(\\S)(\\n[-*+]\\s)",
            "(?m)(\\S)(\\n\\[[ xX]\\]\\s)",
            "(?m)(\\S)(\\n```)",
            "(?m)(\\S)(\\n~~~)",
            "(?m)(\\S)(\\n\\$\\$)",
            "(?m)(\\S)((?:[-*_]\\s*){3,}$)",
        ]
        for p in patterns {
            if let r = try? NSRegularExpression(pattern: p) {
                let range = NSRange(location: 0, length: (t as NSString).length)
                t = r.stringByReplacingMatches(in: t, options: [], range: range, withTemplate: "$1\n\n$2")
            }
        }
        return t
    }

    // MARK: - Segment Parser

    private enum Segment {
        case markdown(String)
        case math(String)
        case mermaid(String)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        let lines = normalized.components(separatedBy: "\n")
        var buf: [String] = []
        var i = 0

        func flush() {
            let t = buf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            buf.removeAll(keepingCapacity: true)
            if !t.isEmpty { result.append(.markdown(t)) }
        }

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            // Mermaid fenced block (```mermaid or ~~~mermaid)
            if let fence = mermaidFence(trimmed) {
                flush()
                var blockLines: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    blockLines.append(lines[i])
                    i += 1
                }
                let block = blockLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !block.isEmpty { result.append(.mermaid(block)) }
                if i < lines.count { i += 1 }
                continue
            }

            // Display math $$...$$
            if trimmed.hasPrefix("$$") && !trimmed.hasPrefix("$$$") {
                flush()
                let after = String(trimmed.dropFirst(2))
                if let close = after.range(of: "$$") {
                    let math = after[after.startIndex..<close.lowerBound]
                        .trimmingCharacters(in: .whitespaces)
                    if !math.isEmpty { result.append(.math(String(math))) }
                    i += 1
                    continue
                }
                // Multi-line
                var mathLines: [String] = []
                i += 1
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if let r = t.range(of: "$$") {
                        mathLines.append(String(t[t.startIndex..<r.lowerBound]))
                        i += 1
                        break
                    }
                    mathLines.append(lines[i])
                    i += 1
                }
                let math = mathLines.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                if !math.isEmpty { result.append(.math(math)) }
                continue
            }

            buf.append(lines[i])
            i += 1
        }
        flush()
        return result
    }

    private func mermaidFence(_ trimmed: String) -> String? {
        for f in ["```", "~~~"] where trimmed.hasPrefix(f) {
            let lang = trimmed.dropFirst(f.count)
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            if lang == "mermaid" { return f }
        }
        return nil
    }
}

// MARK: - Code Block

private struct HermesCodeBlockView: View {
    let configuration: CodeBlockConfiguration
    @State private var didCopy = false

    private var title: String {
        let lang = configuration.language?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (lang?.isEmpty == false ? lang! : "code").uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(D.textSecondary)
                    .tracking(0.04)
                Spacer()
                Button {
                    UIPasteboard.general.string = configuration.content
                    withAnimation(.easeInOut(duration: 0.16)) { didCopy = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(.easeInOut(duration: 0.16)) { didCopy = false }
                    }
                } label: {
                    ZStack {
                        Image(systemName: "doc.on.doc").opacity(didCopy ? 0 : 1)
                        Image(systemName: "checkmark").opacity(didCopy ? 1 : 0)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(didCopy ? D.accent : D.textSecondary)
                    .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(D.surface.opacity(0.8))

            Text(configuration.content.isEmpty ? " " : configuration.content)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(D.textPrimary)
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(D.surface.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(D.border.opacity(0.65), lineWidth: 1)
        )
    }
}

// MARK: - Mermaid

private struct MermaidDiagramView: View {
    let source: String
    @State private var height: CGFloat = 200

    var body: some View {
        MermaidWebView(source: source, height: $height)
            .frame(minHeight: 120, idealHeight: height, maxHeight: max(height, 200))
            .background(D.surface.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(D.border.opacity(0.65), lineWidth: 1)
            )
    }
}

private struct MermaidWebView: UIViewRepresentable {
    let source: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "resize")
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false; view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.scrollView.showsVerticalScrollIndicator = false
        view.scrollView.showsHorizontalScrollIndicator = false
        context.coordinator.webView = view
        view.loadHTMLString(mermaidHTML(source), baseURL: URL(string: "https://cdn.jsdelivr.net"))
        return view
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.last != source {
            context.coordinator.last = source
            wv.loadHTMLString(mermaidHTML(source), baseURL: URL(string: "https://cdn.jsdelivr.net"))
        }
    }

    private func mermaidHTML(_ src: String) -> String {
        let escaped = src
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        return """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;padding:14px;background:transparent;overflow:hidden}
        svg{max-width:100%;height:auto}</style>
        </head><body><div id="d"></div>
        <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
        <script>
        mermaid.initialize({startOnLoad:false,theme:'dark',securityLevel:'loose'});
        document.getElementById('d').innerHTML='<div class="mermaid">\(escaped)</div>';
        mermaid.run({querySelector:'.mermaid'}).then(function(){
          window.webkit.messageHandlers.resize.postMessage(
            Math.max(document.getElementById('d').scrollHeight,120));
        });
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        weak var webView: WKWebView?
        var last: String?
        init(height: Binding<CGFloat>) { self._height = height }
        func userContentController(_: WKUserContentController, didReceive m: WKScriptMessage) {
            if m.name == "resize", let v = m.body as? Double {
                Task { @MainActor in height = max(120, v) }
            }
        }
    }
}

// MARK: - Hermes Theme

extension Theme {
    @MainActor static let hermes = Theme()
        .text {
            FontSize(D.fontSize)
            ForegroundColor(D.textPrimary)
            BackgroundColor(.clear)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            BackgroundColor(D.inlineCodeBg)
        }
        .strong { FontWeight(.semibold) }
        .link {
            ForegroundColor(D.accent)
            UnderlineStyle(.single)
        }

        .heading1 { c in c.label.markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.55)) } }
        .heading2 { c in c.label.markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.28)) } }
        .heading3 { c in c.label.markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.12)) } }
        .heading4 { c in c.label.markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.02)) } }
        .heading5 { c in c.label.markdownTextStyle { FontWeight(.semibold); FontSize(.em(0.94)) } }
        .heading6 { c in c.label.markdownTextStyle { FontWeight(.medium); FontSize(.em(0.88)); ForegroundColor(D.textSecondary) } }

        .paragraph { c in c.label
            .relativeLineSpacing(.em(D.lineHeightEm))
            .markdownMargin(top: 0, bottom: 14)
        }

        .blockquote { c in
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(D.quoteBar).frame(width: 3).padding(.trailing, 8)
                c.label.relativePadding(.vertical, length: .em(0.15))
                    .markdownTextStyle { BackgroundColor(.clear) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: 18, bottom: 20)
        }

        .codeBlock { c in c.label.markdownMargin(top: 18, bottom: 22) }

        .listItem { c in c.label
            .markdownMargin(top: .em(0.18), bottom: .em(0.18))
        }
        .taskListMarker { c in
            Image(systemName: c.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundStyle(c.isCompleted ? D.accent : D.textSecondary)
                .font(.system(size: 18))
                .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
        }

        .table { c in
            ScrollView(.horizontal, showsIndicators: false) {
                c.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: D.border.opacity(0.42)))
                    .markdownTableBackgroundStyle(.alternatingRows(D.surface.opacity(0.18), D.surface.opacity(0.28)))
            }
            .markdownMargin(top: 18, bottom: 22)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(D.border.opacity(0.55), lineWidth: 1))
        }
        .tableCell { c in
            c.label.markdownTextStyle {
                if c.row == 0 { FontWeight(.semibold) }
                BackgroundColor(.clear)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10).padding(.horizontal, 14)
            .relativeLineSpacing(.em(0.22))
        }

        .thematicBreak { Divider().overlay(D.border.opacity(0.75)).markdownMargin(top: 14, bottom: 14) }
}
