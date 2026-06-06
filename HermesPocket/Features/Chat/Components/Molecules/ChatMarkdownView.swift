import SwiftUI
import MarkdownUI
import LaTeXSwiftUI
import WebKit

// MARK: - Design tokens

private enum D {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
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
                        .font(.system(size: 18))
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

    // ── Segment Parser ──

    private enum Segment {
        case markdown(String)
        case math(String)
        case mermaid(String)
    }

    private var segments: [Segment] {
        var out: [Segment] = []
        let lines = markdown.components(separatedBy: "\n")
        var buf: [String] = []
        var i = 0

        func flush() {
            let t = buf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            buf.removeAll(keepingCapacity: true)
            if !t.isEmpty { out.append(.markdown(t)) }
        }

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            // Mermaid fenced block
            if let fence = mermaidFence(trimmed) {
                flush()
                var body: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    body.append(lines[i]); i += 1
                }
                let b = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !b.isEmpty { out.append(.mermaid(b)) }
                if i < lines.count { i += 1 }
                continue
            }

            // Display math $$...$$
            if trimmed.hasPrefix("$$") && !trimmed.hasPrefix("$$$") {
                flush()
                let after = String(trimmed.dropFirst(2))
                if let c = after.range(of: "$$") {
                    let m = after[after.startIndex..<c.lowerBound].trimmingCharacters(in: .whitespaces)
                    if !m.isEmpty { out.append(.math(String(m))) }
                    i += 1
                    continue
                }
                var math: [String] = []
                i += 1
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if let r = t.range(of: "$$") {
                        math.append(String(t[t.startIndex..<r.lowerBound])); i += 1; break
                    }
                    math.append(lines[i]); i += 1
                }
                let m = math.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                if !m.isEmpty { out.append(.math(m)) }
                continue
            }

            buf.append(lines[i]); i += 1
        }
        flush()
        return out
    }

    private func mermaidFence(_ t: String) -> String? {
        for f in ["```", "~~~"] where t.hasPrefix(f) {
            if t.dropFirst(f.count).trimmingCharacters(in: .whitespaces).lowercased() == "mermaid" {
                return f
            }
        }
        return nil
    }
}

// MARK: - Code Block

private struct HermesCodeBlockView: View {
    let configuration: CodeBlockConfiguration
    @State private var didCopy = false

    private var title: String {
        (configuration.language?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty).map { $0.uppercased() } ?? "CODE"
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
                    Task { try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(.easeInOut(duration: 0.16)) { didCopy = false } }
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
            .padding(.horizontal, 12).padding(.vertical, 8)
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
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(D.border.opacity(0.65), lineWidth: 1))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
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
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(D.border.opacity(0.65), lineWidth: 1))
    }
}

private struct MermaidWebView: UIViewRepresentable {
    let source: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let c = WKWebViewConfiguration()
        c.userContentController.add(context.coordinator, name: "resize")
        let v = WKWebView(frame: .zero, configuration: c)
        v.isOpaque = false; v.backgroundColor = .clear
        v.scrollView.backgroundColor = .clear
        v.scrollView.isScrollEnabled = false
        v.scrollView.bounces = false
        context.coordinator.webView = v
        v.loadHTMLString(mermaidHTML(source), baseURL: URL(string: "https://cdn.jsdelivr.net"))
        return v
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.last != source {
            context.coordinator.last = source
            wv.loadHTMLString(mermaidHTML(source), baseURL: URL(string: "https://cdn.jsdelivr.net"))
        }
    }

    private func mermaidHTML(_ src: String) -> String {
        let esc = src.replacingOccurrences(of: "\\", with: "\\\\")
                     .replacingOccurrences(of: "`", with: "\\`")
        return """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;padding:14px;background:transparent;overflow:hidden}svg{max-width:100%;height:auto}</style>
        </head><body><div id="d"></div>
        <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
        <script>
        mermaid.initialize({startOnLoad:false,theme:'dark',securityLevel:'loose'});
        document.getElementById('d').innerHTML='<div class="mermaid">\(esc)</div>';
        mermaid.run({querySelector:'.mermaid'}).then(function(){
          window.webkit.messageHandlers.resize.postMessage(Math.max(document.getElementById('d').scrollHeight,120));
        });
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat; weak var webView: WKWebView?; var last: String?
        init(height: Binding<CGFloat>) { self._height = height }
        func userContentController(_: WKUserContentController, didReceive m: WKScriptMessage) {
            if m.name == "resize", let v = m.body as? Double {
                Task { @MainActor in height = max(120, v) }
            }
        }
    }
}

// MARK: - Theme

extension Theme {
    @MainActor static let hermes = Theme()
        .text {
            FontSize(18)
            ForegroundColor(D.textPrimary)
            BackgroundColor(.clear)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            BackgroundColor(D.inlineCodeBg)
        }
        .strong { FontWeight(.semibold) }
        .link { ForegroundColor(D.accent); UnderlineStyle(.single) }

        .heading1 { c in c.label.markdownMargin(top: 22, bottom: 18)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.55)) } }
        .heading2 { c in c.label.markdownMargin(top: 18, bottom: 17)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.28)) } }
        .heading3 { c in c.label.markdownMargin(top: 16, bottom: 16)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.12)) } }
        .heading4 { c in c.label.markdownMargin(top: 14, bottom: 15)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.02)) } }
        .heading5 { c in c.label.markdownMargin(top: 12, bottom: 14)
            .markdownTextStyle { FontWeight(.semibold); FontSize(.em(0.94)) } }
        .heading6 { c in c.label.markdownMargin(top: 12, bottom: 14)
            .markdownTextStyle { FontWeight(.medium); FontSize(.em(0.88)); ForegroundColor(D.textSecondary) } }

        .paragraph { c in c.label.fixedSize(horizontal: false, vertical: true)
            .relativeLineSpacing(.em(0.33)).markdownMargin(top: 0, bottom: 14) }

        .blockquote { c in
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(D.quoteBar).frame(width: 3).padding(.trailing, 8)
                c.label.relativePadding(.vertical, length: .em(0.15))
                    .markdownTextStyle { BackgroundColor(.clear) }
            }.fixedSize(horizontal: false, vertical: true).markdownMargin(top: 10, bottom: 14)
        }

        .codeBlock { c in c.label.markdownMargin(top: 18, bottom: 22) }

        .listItem { c in c.label.markdownMargin(top: .em(0.18), bottom: .em(0.18)) }

        .taskListMarker { c in
            Image(systemName: c.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundStyle(c.isCompleted ? D.accent : D.textSecondary)
                .font(.system(size: 18))
                .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
        }

        .table { c in
            ScrollView(.horizontal, showsIndicators: false) {
                c.label.fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: D.border.opacity(0.42)))
                    .markdownTableBackgroundStyle(.alternatingRows(D.surface.opacity(0.18), D.surface.opacity(0.28)))
            }
            .markdownMargin(top: 18, bottom: 22)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(D.border.opacity(0.55), lineWidth: 1))
        }
        .tableCell { c in
            c.label.markdownTextStyle {
                if c.row == 0 { FontWeight(.semibold); BackgroundColor(D.surface.opacity(0.5)) }
                else { BackgroundColor(.clear) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10).padding(.horizontal, 14)
            .relativeLineSpacing(.em(0.22))
        }

        .thematicBreak { Divider().overlay(D.border.opacity(0.75)).markdownMargin(top: 14, bottom: 14) }
}
