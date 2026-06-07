import SwiftUI
import MarkdownUI
import LaTeXSwiftUI
import WebKit

// MARK: - Main View

struct ChatMarkdownView: View {
    let markdown: String
    let isStreaming: Bool

    var body: some View {
        content
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        let src = normalize(markdown)
        if src.nilIfEmpty == nil {
            Text("_ _").foregroundStyle(.white.opacity(0.4))
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(segments(from: src).enumerated()), id: \.offset) { _, seg in
                    switch seg {
                    case .markdown(let text):
                        Markdown(text)
                            .markdownTheme(.hermes)
                            .markdownBlockStyle(\.codeBlock) { config in
                                CodeBlockView(configuration: config)
                            }
                    case .math(let text):
                        LaTeX(text)
                            .blockMode(.blockViews)
                            .errorMode(.original)
                            .font(.system(size: 18))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .padding(.vertical, 8)
                    case .mermaid(let text):
                        MermaidView(source: text)
                            .padding(.vertical, 6)
                    }
                }
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

private func segments(from src: String) -> [Segment] {
    var out: [Segment] = []
    let lines = src.components(separatedBy: "\n")
    var buf: [String] = []
    var i = 0

    func flush() {
        let t = buf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        buf.removeAll(keepingCapacity: true)
        if !t.isEmpty { out.append(.markdown(t)) }
    }

    while i < lines.count {
        let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

        // Mermaid
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

        // Display math $$
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
        if t.dropFirst(f.count).trimmingCharacters(in: .whitespaces).lowercased() == "mermaid" { return f }
    }
    return nil
}

// MARK: - Normalize (ensure code fences are detected)

private func normalize(_ src: String) -> String {
    var t = src.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")

    // 1. Add blank line before existing fences (bare ``` or ```language)
    if let r = try? NSRegularExpression(pattern: "(?m)(\\S)(\\n```)") {
        let range = NSRange(location: 0, length: t.utf16.count)
        t = r.stringByReplacingMatches(in: t, range: range, withTemplate: "$1\n\n$2")
    }
    if let r = try? NSRegularExpression(pattern: "(?m)(\\S)(\\n```[a-zA-Z])") {
        let range = NSRange(location: 0, length: t.utf16.count)
        t = r.stringByReplacingMatches(in: t, range: range, withTemplate: "$1\n\n$2")
    }

    // 2. Detect indented code blocks and wrap in fences
    let lines = t.components(separatedBy: "\n")
    var out: [String] = []
    var i = 0
    while i < lines.count {
        let line = lines[i]
        // Skip already-fenced
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            out.append(line); i += 1
            while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                out.append(lines[i]); i += 1
            }
            if i < lines.count { out.append(lines[i]); i += 1 }
            continue
        }

        // Check if next line is more indented
        if i + 1 < lines.count, !line.isEmpty {
            let next = lines[i + 1]
            let thisIndent = line.prefix(while: { $0 == " " }).count
            let nextIndent = next.prefix(while: { $0 == " " || $0 == "\t" }).count
            if nextIndent >= thisIndent + 2 && !next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                out.append("```")
                // Include this line and all subsequent indented/non-empty lines
                while i < lines.count {
                    let li = lines[i]
                    let indent = li.prefix(while: { $0 == " " || $0 == "\t" }).count
                    let trimmed = li.trimmingCharacters(in: .whitespacesAndNewlines)
                    if indent >= thisIndent && (!trimmed.isEmpty || li.isEmpty) {
                        out.append(li); i += 1
                    } else { break }
                }
                out.append("```")
                continue
            }
        }
        out.append(line); i += 1
    }
    return out.joined(separator: "\n")
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Code Block View

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
                    .textSelection(.disabled)
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
                    .textSelection(.disabled)
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

// MARK: - Mermaid View

private struct MermaidView: View {
    let source: String
    @State private var height: CGFloat = 200

    var body: some View {
        MermaidWebView(source: source, height: $height)
            .frame(minHeight: 120, idealHeight: height, maxHeight: max(height, 200))
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

private struct MermaidWebView: UIViewRepresentable {
    let source: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "resize")
        let v = WKWebView(frame: .zero, configuration: config)
        v.isOpaque = false; v.backgroundColor = .clear
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
        let esc = src.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`")
        return """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;padding:14px;background:transparent;overflow:hidden}svg{max-width:100%;height:auto}</style>
        </head><body><div id="d"></div>
        <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
        <script>mermaid.initialize({startOnLoad:false,theme:'dark',securityLevel:'loose'});
        document.getElementById('d').innerHTML='<div class="mermaid">\(esc)</div>';
        mermaid.run({querySelector:'.mermaid'}).then(function(){
          window.webkit.messageHandlers.resize.postMessage(Math.max(document.getElementById('d').scrollHeight,120));
        });</script></body></html>
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
