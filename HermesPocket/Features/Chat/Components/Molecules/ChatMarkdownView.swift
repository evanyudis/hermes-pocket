import SwiftUI
import MarkdownUI
import LaTeXSwiftUI
import WebKit

// MARK: - Content Segment Parser

private enum ContentSegment: Equatable {
    case markdown(String)
    case mathBlock(String)
    case mermaidBlock(String)
}

private func parseContentSegments(_ raw: String) -> [ContentSegment] {
    var segments: [ContentSegment] = []
    var currentMarkdown = ""
    var i = raw.startIndex

    while i < raw.endIndex {
        // Check for $$ math block
        if raw[i...].hasPrefix("$$") {
            // Flush pending markdown
            if !currentMarkdown.isEmpty {
                segments.append(.markdown(currentMarkdown))
                currentMarkdown = ""
            }
            let start = raw.index(i, offsetBy: 2)
            if let end = raw[start...].range(of: "$$") {
                let math = String(raw[start..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !math.isEmpty {
                    segments.append(.mathBlock(math))
                }
                i = raw.index(end.upperBound, offsetBy: 0)
            } else {
                currentMarkdown.append("$$")
                i = raw.index(i, offsetBy: 2)
            }
            continue
        }

        // Check for ```mermaid block
        if raw[i...].hasPrefix("```mermaid") || raw[i...].hasPrefix("``` mermaid") {
            if !currentMarkdown.isEmpty {
                segments.append(.markdown(currentMarkdown))
                currentMarkdown = ""
            }
            // Find the end of this line
            let lineEnd = raw[i...].firstIndex(of: "\n") ?? raw.endIndex
            let afterLang = lineEnd == raw.endIndex ? raw.endIndex : raw.index(lineEnd, offsetBy: 1)
            if afterLang < raw.endIndex,
               let end = raw[afterLang...].range(of: "\n```") {
                let source = String(raw[afterLang..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !source.isEmpty {
                    segments.append(.mermaidBlock(source))
                }
                // Find the closing ``` line
                let closeStart = raw.index(end.upperBound, offsetBy: 0)
                let closeLineEnd = raw[closeStart...].firstIndex(of: "\n") ?? raw.endIndex
                i = closeLineEnd
            } else {
                // Malformed, treat as markdown
                currentMarkdown.append("```mermaid")
                i = raw.index(i, offsetBy: 10)
            }
            continue
        }

        currentMarkdown.append(raw[i])
        i = raw.index(after: i)
    }

    if !currentMarkdown.isEmpty {
        segments.append(.markdown(currentMarkdown))
    }

    return segments
}

// MARK: - ChatMarkdownView

struct ChatMarkdownView: View {
    let markdown: String
    let isStreaming: Bool

    var body: some View {
        let segments = parseContentSegments(markdown)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .markdown(let text):
                    MarkdownSegmentView(text: text)
                case .mathBlock(let tex):
                    MathBlockView(tex: tex)
                case .mermaidBlock(let source):
                    MermaidBlockView(source: source)
                }
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Markdown Segment

private struct MarkdownSegmentView: View {
    let text: String

    var body: some View {
        Markdown(text)
            .markdownTheme(.hermes)
            .markdownCodeSyntaxHighlighter(.plainText)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Hermes Markdown Theme

extension Theme {
    @MainActor static let hermes = Theme()
        .text {
            FontSize(18)
            ForegroundColor(.primary)
        }
        .codeBlock { configuration in
            HermesCodeBlockView(configuration: configuration)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(.white.opacity(0.08))
        }
        .blockquote { configuration in
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 3)
                configuration.label
                    .padding(.leading, 12)
            }
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(.white.opacity(0.12), strokeStyle: .init(lineWidth: 0.5)))
                .markdownTableBackgroundStyle(.alternatingRows(Color.white.opacity(0.04), Color.clear))
        }
        .tableCell { configuration in
            configuration.label
                .markdownTableCellBorderStyle(.init(.white.opacity(0.08), strokeStyle: .init(lineWidth: 0.5)))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .listBullet { _ in
            Text("•")
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isCompleted ? Color.green : Color.white.opacity(0.4))
                .imageScale(.small)
        }
        .heading1 { configuration in
            configuration.label
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
        .heading2 { configuration in
            configuration.label
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 10)
                .padding(.bottom, 2)
        }
        .heading3 { configuration in
            configuration.label
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.top, 8)
                .padding(.bottom, 2)
        }
        .paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: 0, bottom: 8)
        }
}

// MARK: - Code Block with Copy Button

private struct HermesCodeBlockView: View {
    let configuration: CodeBlockConfiguration
    @State private var didCopy = false

    private var title: String {
        let language = configuration.language?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (language?.isEmpty == false ? language! : "code").uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                // Copy button
                Button {
                    UIPasteboard.general.string = configuration.content
                    withAnimation(.easeOut(duration: 0.2)) {
                        didCopy = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            didCopy = false
                        }
                    }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(didCopy ? Color.green : Color.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                }

                Spacer()

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .relativePadding(.horizontal, length: .rem(1))
                    .relativePadding(.vertical, length: .rem(0.8))
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.vertical, 4)
    }
}

// MARK: - Math Block

private struct MathBlockView: View {
    let tex: String

    var body: some View {
        LaTeX(tex)
            .font(.system(size: 18))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .errorMode(.original)
            .blockMode(.blockViews)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Mermaid Block

private struct MermaidBlockView: View {
    let source: String
    @State private var height: CGFloat = 220

    var body: some View {
        MermaidWebView(source: source, height: $height)
            .frame(minHeight: 160, idealHeight: height, maxHeight: max(height, 200))
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.vertical, 4)
    }
}

private struct MermaidWebView: UIViewRepresentable {
    let source: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "resize")
        config.userContentController = controller

        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        view.loadHTMLString(mermaidHTML, baseURL: nil)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.pendingSource = source
        if context.coordinator.didFinishLoad {
            context.coordinator.renderPendingSource()
        }
    }

    private var mermaidHTML: String {
        """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>body{margin:0;background:transparent;display:flex;justify-content:center;align-items:center;min-height:100vh;}
        svg{max-width:100%!important;height:auto!important;}</style>
        <script>window.mermaidConfig={startOnLoad:false,theme:'dark',securityLevel:'loose',fontFamily:'system-ui'};</script>
        <script src="mermaid.min.js"></script>
        </head><body><div id="mermaid"></div></body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var height: CGFloat
        weak var webView: WKWebView?
        var pendingSource = ""
        var didFinishLoad = false

        init(height: Binding<CGFloat>) {
            self._height = height
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didFinishLoad = true
            renderPendingSource()
        }

        func renderPendingSource() {
            guard !pendingSource.isEmpty else { return }
            let source = pendingSource
            pendingSource = ""
            let escaped = source
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = """
            (async function(){
              var el=document.getElementById('mermaid');
              el.textContent='';
              el.removeAttribute('data-processed');
              try{
                var d=document.createElement('div');
                d.textContent=`\(escaped)`;
                el.appendChild(d);
                await mermaid.run({nodes:[el]});
                var h=el.scrollHeight || 200;
                window.webkit.messageHandlers.resize.postMessage(h);
              }catch(e){
                el.innerHTML='<pre style="color:#999;padding:16px;font-size:13px;">'+e.message+'</pre>';
                window.webkit.messageHandlers.resize.postMessage(160);
              }
            })();
            """
            webView?.evaluateJavaScript(js)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "resize", let h = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.height = h
                }
            }
        }
    }
}
