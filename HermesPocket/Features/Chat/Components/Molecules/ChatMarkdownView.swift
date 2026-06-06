import SwiftUI
import MarkdownUI
import LaTeXSwiftUI
import WebKit

// MARK: - Colors

private enum C {
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let surface = Color.white.opacity(0.06)
    static let accent = Color(red: 0.04, green: 0.52, blue: 1.0) // #0A84FF
    static let border = Color.white.opacity(0.10)
    static let codeBg = Color.white.opacity(0.07)
    static let inlineCodeBg = Color.white.opacity(0.12)
    static let quoteBar = Color.white.opacity(0.28)
}

// MARK: - Main View

struct ChatMarkdownView: View {
    let markdown: String
    let isStreaming: Bool

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
                        .font(.system(size: 17))
                        .foregroundStyle(C.textPrimary)
                        .textSelection(.enabled)
                        .padding(.vertical, 8)
                case .mermaid(let text):
                    MermaidDiagramView(source: text)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - Segment Parser

    private enum Segment {
        case markdown(String)
        case math(String)
        case mermaid(String)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        let lines = markdown.components(separatedBy: "\n")
        var buf: [String] = []
        var i = 0

        func flush() {
            let t = buf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            buf.removeAll(keepingCapacity: true)
            if !t.isEmpty { result.append(.markdown(t)) }
        }

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            // Mermaid fenced block
            if trimmed.hasPrefix("```mermaid") || trimmed.hasPrefix("~~~mermaid") {
                flush()
                let fence = trimmed.hasPrefix("```") ? "```" : "~~~"
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

            // Display math $$...$$ (inline or multi-line)
            if trimmed.hasPrefix("$$") {
                flush()
                let afterOpen = String(trimmed.dropFirst(2))
                if let close = afterOpen.range(of: "$$") {
                    let math = afterOpen[afterOpen.startIndex..<close.lowerBound]
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(C.textSecondary)
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(didCopy ? C.accent : C.textSecondary)
                    .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(C.surface.opacity(0.78))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(configuration.content.isEmpty ? " " : configuration.content)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(C.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(C.surface.opacity(0.42))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(C.border.opacity(0.65), lineWidth: 1)
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
            .background(C.surface.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(C.border.opacity(0.65), lineWidth: 1)
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
        let escaped = src.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        return """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;padding:12px;background:transparent;overflow:hidden}
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

// MARK: - Hermes Theme (MarkdownUI)

extension Theme {
    @MainActor static let hermes = Theme()
        // -- inline text --
        .text {
            ForegroundColor(C.textPrimary)
            BackgroundColor(.clear)
            FontSize(17)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            BackgroundColor(C.inlineCodeBg)
        }
        .strong { FontWeight(.semibold) }
        .link {
            ForegroundColor(C.accent)
            UnderlineStyle(.single)
        }

        // -- headings --
        .heading1 { c in c.label.relativeLineSpacing(.em(0.12)).markdownMargin(top: 22, bottom: 18)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.55)) } }
        .heading2 { c in c.label.relativeLineSpacing(.em(0.12)).markdownMargin(top: 18, bottom: 17)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.28)) } }
        .heading3 { c in c.label.relativeLineSpacing(.em(0.12)).markdownMargin(top: 16, bottom: 16)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.12)) } }
        .heading4 { c in c.label.relativeLineSpacing(.em(0.12)).markdownMargin(top: 14, bottom: 15)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.02)) } }
        .heading5 { c in c.label.relativeLineSpacing(.em(0.12)).markdownMargin(top: 12, bottom: 14)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(0.94)) } }
        .heading6 { c in c.label.relativeLineSpacing(.em(0.12)).markdownMargin(top: 12, bottom: 14)
            .markdownTextStyle { FontWeight(.medium); FontSize(.em(0.88)); ForegroundColor(C.textSecondary) } }

        // -- paragraph --
        .paragraph { c in c.label.fixedSize(horizontal: false, vertical: true)
            .relativeLineSpacing(.em(0.24)).markdownMargin(top: 0, bottom: 14) }

        // -- blockquote --
        .blockquote { c in
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(C.quoteBar).relativeFrame(width: .em(0.2))
                c.label.relativePadding(.leading, length: .em(0.9))
                    .relativePadding(.vertical, length: .em(0.15))
                    .markdownTextStyle { BackgroundColor(.clear) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: 18, bottom: 20)
        }

        // -- code block (overridden by `markdownBlockStyle`, but kept as fallback) --
        .codeBlock { c in
            c.label.markdownMargin(top: 18, bottom: 22)
        }

        // -- lists --
        .listItem { c in c.label.fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: .em(0.18), bottom: .em(0.18)) }
        .taskListMarker { c in
            Image(systemName: c.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundStyle(c.isCompleted ? C.accent : C.textSecondary)
                .imageScale(.small)
                .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
        }

        // -- table --
        .table { c in
            ScrollView(.horizontal, showsIndicators: false) {
                c.label.fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: C.border.opacity(0.42)))
                    .markdownTableBackgroundStyle(.alternatingRows(C.surface.opacity(0.18), C.surface.opacity(0.28)))
            }
            .markdownMargin(top: 18, bottom: 22)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.border.opacity(0.55), lineWidth: 1))
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

        // -- divider --
        .thematicBreak { Divider().overlay(C.border.opacity(0.75)).markdownMargin(top: 14, bottom: 14) }
}
