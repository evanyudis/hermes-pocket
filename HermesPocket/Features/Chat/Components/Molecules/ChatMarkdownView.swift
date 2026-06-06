import SwiftUI
import WebKit
import UIKit

extension Notification.Name {
    static let chatDismissTextSelection = Notification.Name("chatDismissTextSelection")
}

struct ChatMarkdownView: View {
    let markdown: String
    let isStreaming: Bool
    @State private var contentHeight: CGFloat = 24

    var body: some View {
        ChatMarkdownWebView(markdown: markdown, isStreaming: isStreaming, contentHeight: $contentHeight)
            .frame(height: max(contentHeight, 24))
    }
}

private struct ChatMarkdownWebView: UIViewRepresentable {
    let markdown: String
    let isStreaming: Bool
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "resize")
        controller.add(context.coordinator, name: "copy")
        config.userContentController = controller
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.scrollView.showsVerticalScrollIndicator = false
        view.scrollView.showsHorizontalScrollIndicator = false
        context.coordinator.webView = view
        if let baseURL = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true) {
            view.loadHTMLString(Self.htmlShell, baseURL: baseURL)
        } else {
            view.loadHTMLString(Self.htmlShell, baseURL: nil)
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.pendingMarkdown = markdown
        context.coordinator.isStreaming = isStreaming
        if context.coordinator.didFinishInitialLoad {
            context.coordinator.scheduleRender(markdown: markdown, isStreaming: isStreaming)
        }
    }

    static let htmlShell = """
    <!doctype html>
    <html>
    <head>
      <meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no\">
      <link rel=\"stylesheet\" href=\"highlight-github-dark.min.css\">
      <link rel=\"stylesheet\" href=\"katex.min.css\">
      <style>
        :root {
          color-scheme: dark;
          --fg: rgba(255,255,255,0.96);
          --muted: rgba(255,255,255,0.72);
          --quote: rgba(255,255,255,0.16);
          --code-bg: rgba(255,255,255,0.08);
          --inline-code-bg: rgba(255,255,255,0.10);
          --border: rgba(255,255,255,0.10);
          --link: #8ab4ff;
          --surface: rgba(255,255,255,0.06);
          --surface-strong: rgba(255,255,255,0.12);
          --success: #34c759;
        }
        * { box-sizing: border-box; }
        html, body {
          margin: 0;
          padding: 0;
          background: transparent;
          color: var(--fg);
          font-family: -apple-system, BlinkMacSystemFont, \"SF Pro Text\", sans-serif;
          font-size: 18px;
          line-height: 1.5;
          overflow: hidden;
          word-wrap: break-word;
          -webkit-user-select: text;
          user-select: text;
        }
        #content {
          padding: 0;
          margin: 0;
        }
        p, ul, ol, blockquote, pre, table, .mermaid-wrap, h1, h2, h3, h4, h5, h6 {
          margin: 0 0 0.8em 0;
        }
        p:last-child, ul:last-child, ol:last-child, blockquote:last-child, pre:last-child, table:last-child, .mermaid-wrap:last-child {
          margin-bottom: 0;
        }
        h1, h2, h3, h4, h5, h6 {
          line-height: 1.25;
          font-weight: 650;
        }
        h1 { font-size: 1.5em; }
        h2 { font-size: 1.35em; }
        h3 { font-size: 1.2em; }
        a { color: var(--link); text-decoration: none; }
        strong { font-weight: 700; }
        em { font-style: italic; }
        code {
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          font-size: 0.92em;
        }
        :not(pre) > code {
          background: var(--inline-code-bg);
          border-radius: 8px;
          padding: 0.15em 0.35em;
        }
        pre {
          background: transparent;
          border: 0;
          border-radius: 0;
          padding: 0;
          margin: 0;
          overflow-x: auto;
          -webkit-overflow-scrolling: touch;
        }
        pre code {
          background: transparent;
          padding: 0;
          font-size: 0.88em;
        }
        blockquote {
          border-left: 3px solid var(--quote);
          margin-left: 0;
          padding-left: 14px;
          color: var(--muted);
        }
        ul, ol {
          padding-left: 1.4em;
        }
        li + li {
          margin-top: 0.25em;
        }
        hr {
          border: 0;
          border-top: 1px solid var(--border);
          margin: 1em 0;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          display: block;
          overflow-x: auto;
        }
        th, td {
          border: 1px solid var(--border);
          padding: 8px 10px;
          text-align: left;
          vertical-align: top;
          max-width: 220px;
          white-space: normal;
          overflow-wrap: anywhere;
          word-break: break-word;
        }
        .block-shell {
          background: var(--code-bg);
          border: 1px solid var(--border);
          border-radius: 14px;
          margin: 0 0 0.8em 0;
          overflow: hidden;
        }
        .block-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 10px;
          padding: 10px 12px;
          border-bottom: 1px solid var(--border);
          background: var(--surface);
        }
        .block-label {
          color: var(--muted);
          font-size: 12px;
          font-weight: 600;
          letter-spacing: 0.04em;
          text-transform: uppercase;
        }
        .copy-button {
          appearance: none;
          border: 1px solid var(--border);
          background: var(--surface);
          color: var(--fg);
          border-radius: 999px;
          width: 30px;
          height: 30px;
          padding: 0;
          font: inherit;
          font-size: 14px;
          font-weight: 700;
          line-height: 1;
          display: inline-flex;
          align-items: center;
          justify-content: center;
        }
        .copy-button.copied {
          background: color-mix(in srgb, var(--success) 18%, var(--surface));
          border-color: color-mix(in srgb, var(--success) 45%, var(--border));
          color: var(--success);
        }
        .block-body {
          padding: 12px;
          overflow-x: auto;
          -webkit-overflow-scrolling: touch;
        }
        .block-body pre {
          overflow: visible;
        }
        .block-shell:last-child {
          margin-bottom: 0;
        }
        .katex-display {
          overflow-x: auto;
          overflow-y: hidden;
          padding: 0.15em 0;
        }
        .mermaid-wrap {
          overflow-x: auto;
        }
        .mermaid {
          min-width: fit-content;
        }
        .mermaid svg {
          display: block;
          max-width: 100%;
          height: auto;
        }
      </style>
    </head>
    <body>
      <div id=\"content\"></div>
      <script src=\"markdown-it.min.js\"></script>
      <script src=\"highlight-common.min.js\"></script>
      <script defer src=\"katex.min.js\"></script>
      <script defer src=\"katex-auto-render.min.js\"></script>
      <script src=\"mermaid.min.js\"></script>
      <script>
        const md = window.markdownit({
          html: false,
          linkify: true,
          breaks: true,
          typographer: true,
          highlight: (str, lang) => {
            const escaped = md.utils.escapeHtml(str);
            if (lang && window.hljs && hljs.getLanguage(lang)) {
              try {
                const highlighted = hljs.highlight(str, { language: lang, ignoreIllegals: true }).value;
                return `<pre><code class=\"hljs language-${lang}\">${highlighted}</code></pre>`;
              } catch (_) {}
            }
            return `<pre><code class=\"hljs\">${escaped}</code></pre>`;
          }
        });

        function decodeBase64Unicode(value) {
          const binary = atob(value);
          const bytes = Uint8Array.from(binary, c => c.charCodeAt(0));
          return new TextDecoder().decode(bytes);
        }

        function postHeight() {
          const height = Math.max(
            document.body.scrollHeight,
            document.documentElement.scrollHeight,
            document.getElementById('content').scrollHeight
          );
          window.webkit.messageHandlers.resize.postMessage(height);
        }

        function makeCopyButton(label, text) {
          const button = document.createElement('button');
          button.className = 'copy-button';
          button.type = 'button';
          button.setAttribute('aria-label', `Copy ${label}`);
          button.innerHTML = '<span>⧉</span>';
          button.addEventListener('click', () => {
            window.webkit.messageHandlers.copy.postMessage({ text });
            button.classList.add('copied');
            button.innerHTML = '<span>✓</span>';
            clearTimeout(button._copyResetTimer);
            button._copyResetTimer = setTimeout(() => {
              button.classList.remove('copied');
              button.innerHTML = '<span>⧉</span>';
            }, 1600);
          });
          return button;
        }

        function makeBlockShell(label, copyText, contentNode) {
          const shell = document.createElement('div');
          shell.className = 'block-shell';
          const header = document.createElement('div');
          header.className = 'block-header';
          const title = document.createElement('div');
          title.className = 'block-label';
          title.textContent = label;
          header.appendChild(title);
          header.appendChild(makeCopyButton(label, copyText));
          const body = document.createElement('div');
          body.className = 'block-body';
          body.appendChild(contentNode);
          shell.appendChild(header);
          shell.appendChild(body);
          return shell;
        }

        function upgradeCodeBlocks() {
          const blocks = Array.from(document.querySelectorAll('pre > code'));
          for (const code of blocks) {
            if (code.classList.contains('language-mermaid') || code.classList.contains('language-math')) {
              continue;
            }
            const pre = code.parentElement;
            const langClass = Array.from(code.classList).find(name => name.startsWith('language-'));
            const lang = langClass ? langClass.replace('language-', '') : 'code';
            pre.replaceWith(makeBlockShell(lang, code.textContent || '', pre));
          }
        }

        function upgradeMathBlocks() {
          const blocks = Array.from(document.querySelectorAll('pre > code.language-math'));
          for (const code of blocks) {
            const pre = code.parentElement;
            const wrapper = document.createElement('div');
            wrapper.className = 'katex-display';
            try {
              katex.render(code.textContent, wrapper, { displayMode: true, throwOnError: false });
              pre.replaceWith(makeBlockShell('math', code.textContent || '', wrapper));
            } catch (_) {}
          }
        }

        async function upgradeMermaidBlocks() {
          const blocks = Array.from(document.querySelectorAll('pre > code.language-mermaid'));
          for (const code of blocks) {
            const pre = code.parentElement;
            const source = code.textContent || '';
            const wrapper = document.createElement('div');
            wrapper.className = 'mermaid-wrap';
            const target = document.createElement('div');
            target.className = 'mermaid';
            target.textContent = source;
            wrapper.appendChild(target);
            pre.replaceWith(makeBlockShell('mermaid', source, wrapper));
          }
          if (blocks.length > 0) {
            mermaid.initialize({ startOnLoad: false, theme: 'dark', securityLevel: 'loose' });
            await mermaid.run({ querySelector: '.mermaid' });
          }
        }

        async function renderMarkdown(base64) {
          const markdown = decodeBase64Unicode(base64);
          const content = document.getElementById('content');
          content.innerHTML = md.render(markdown);
          upgradeCodeBlocks();
          if (window.renderMathInElement) {
            renderMathInElement(content, {
              delimiters: [
                { left: '$$', right: '$$', display: true },
                { left: '$', right: '$', display: false },
                { left: '\\(', right: '\\)', display: false },
                { left: '\\[', right: '\\]', display: true }
              ],
              throwOnError: false
            });
          }
          upgradeMathBlocks();
          await upgradeMermaidBlocks();
          postHeight();
          setTimeout(postHeight, 50);
          setTimeout(postHeight, 200);
        }

        const observer = new MutationObserver(() => postHeight());
        observer.observe(document.getElementById('content'), { childList: true, subtree: true, attributes: true, characterData: true });
        window.addEventListener('load', postHeight);
        window.addEventListener('resize', postHeight);
        window.clearSelection = () => {
          const selection = window.getSelection();
          if (selection) {
            selection.removeAllRanges();
          }
          if (document.activeElement && typeof document.activeElement.blur === 'function') {
            document.activeElement.blur();
          }
        };
        window.renderMarkdown = renderMarkdown;
      </script>
    </body>
    </html>
    """

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var contentHeight: CGFloat
        weak var webView: WKWebView?
        var pendingMarkdown = ""
        var didFinishInitialLoad = false
        var isStreaming = false
        private var pendingWorkItem: DispatchWorkItem?

        init(contentHeight: Binding<CGFloat>) {
            self._contentHeight = contentHeight
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleDismissTextSelection),
                name: .chatDismissTextSelection,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didFinishInitialLoad = true
            scheduleRender(markdown: pendingMarkdown, isStreaming: isStreaming)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "resize":
                if let value = message.body as? Double {
                    Task { @MainActor in
                        contentHeight = max(24, value)
                    }
                }
            case "copy":
                if let body = message.body as? [String: Any], let text = body["text"] as? String {
                    UIPasteboard.general.string = text
                }
            default:
                break
            }
        }

        func scheduleRender(markdown: String, isStreaming: Bool) {
            pendingWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.render(markdown: markdown)
            }
            pendingWorkItem = workItem
            let delay: TimeInterval = isStreaming ? 0.06 : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        func render(markdown: String) {
            guard let webView else { return }
            let encoded = Data(markdown.utf8).base64EncodedString()
            let script = "window.renderMarkdown(\(jsonStringLiteral(encoded)));"
            webView.evaluateJavaScript(script)
        }

        @objc
        private func handleDismissTextSelection() {
            clearSelection()
        }

        private func clearSelection() {
            webView?.evaluateJavaScript("window.clearSelection && window.clearSelection();")
        }

        private func jsonStringLiteral(_ string: String) -> String {
            let data = try? JSONSerialization.data(withJSONObject: [string], options: [])
            let json = String(data: data ?? Data("[\"\"]".utf8), encoding: .utf8) ?? "[\"\"]"
            return String(json.dropFirst().dropLast())
        }
    }
}
