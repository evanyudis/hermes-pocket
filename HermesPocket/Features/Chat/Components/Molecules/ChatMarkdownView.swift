import SwiftUI
import WebKit
import UIKit

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

        // Write HTML + assets to temp directory, then load via file URL
        if let tempDir = prepareTempAssets() {
            view.loadFileURL(tempDir.appendingPathComponent("markdown.html"), allowingReadAccessTo: tempDir)
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

    // MARK: - Temp Asset Preparation

    private func prepareTempAssets() -> URL? {
        let fm = FileManager.default
        guard let cache = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = cache.appendingPathComponent("hermes-markdown")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        // Copy JS/CSS assets from bundle to temp dir
        let assets = [
            "markdown-it.min.js",
            "highlight-common.min.js",
            "highlight-github-dark.min.css",
            "katex.min.js",
            "katex.min.css",
            "katex-auto-render.min.js",
            "mermaid.min.js",
        ]
        for asset in assets {
            let dest = dir.appendingPathComponent(asset)
            if !fm.fileExists(atPath: dest.path),
               let srcPath = Bundle.main.path(forResource: asset.replacingOccurrences(of: ".min.", with: "").split(separator: ".").first.map(String.init) ?? asset, ofType: nil) ?? Bundle.main.url(forResource: asset, withExtension: nil)?.path,
               let srcPath2 = Bundle.main.path(forResource: asset, ofType: nil) {
                try? fm.copyItem(atPath: srcPath2, toPath: dest.path)
            } else if !fm.fileExists(atPath: dest.path) {
                // Try loading from bundle root directly
                if let src = Bundle.main.url(forResource: asset, withExtension: nil) {
                    try? fm.copyItem(at: src, to: dest)
                }
            }
        }

        // Also try direct path
        for asset in assets {
            let dest = dir.appendingPathComponent(asset)
            if !fm.fileExists(atPath: dest.path) {
                let bundleFile = Bundle.main.bundleURL.appendingPathComponent(asset)
                if fm.fileExists(atPath: bundleFile.path) {
                    try? fm.copyItem(at: bundleFile, to: dest)
                }
            }
        }

        // Write HTML file with local asset references
        let htmlPath = dir.appendingPathComponent("markdown.html")
        if !fm.fileExists(atPath: htmlPath.path) {
            try? Self.htmlShell.write(to: htmlPath, atomically: true, encoding: .utf8)
        }
        return dir
    }

    // MARK: - HTML Shell

    static let htmlShell = """
    <!doctype html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
      <link rel="stylesheet" href="highlight-github-dark.min.css">
      <link rel="stylesheet" href="katex.min.css">
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
          --success: #34c759;
        }
        * { box-sizing: border-box; }
        html, body {
          margin: 0;
          padding: 0;
          background: transparent;
          color: var(--fg);
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          font-size: 18px;
          line-height: 1.5;
          overflow: hidden;
          word-wrap: break-word;
          -webkit-user-select: text;
          user-select: text;
        }
        #content { padding: 0; margin: 0; }
        p, ul, ol, blockquote, pre, table, h1, h2, h3, h4, h5, h6 { margin: 0 0 0.8em 0; }
        p:last-child, ul:last-child, ol:last-child, blockquote:last-child, pre:last-child, table:last-child { margin-bottom: 0; }
        h1, h2, h3, h4, h5, h6 { line-height: 1.25; font-weight: 650; }
        h1 { font-size: 1.5em; } h2 { font-size: 1.35em; } h3 { font-size: 1.2em; }
        a { color: var(--link); text-decoration: none; }
        strong { font-weight: 700; } em { font-style: italic; }
        code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.92em; }
        :not(pre) > code { background: var(--inline-code-bg); border-radius: 8px; padding: 0.15em 0.35em; }
        pre { background: transparent; border: 0; border-radius: 0; padding: 0; margin: 0; overflow-x: auto; }
        pre code { background: transparent; padding: 0; font-size: 0.88em; }
        blockquote { border-left: 3px solid var(--quote); margin-left: 0; padding-left: 14px; color: var(--muted); }
        ul, ol { padding-left: 1.4em; } li + li { margin-top: 0.25em; }
        hr { border: 0; border-top: 1px solid var(--border); margin: 1em 0; }
        table { width: 100%; border-collapse: collapse; display: block; overflow-x: auto; }
        th, td { border: 1px solid var(--border); padding: 8px 10px; text-align: left; vertical-align: top; max-width: 220px; white-space: normal; overflow-wrap: anywhere; word-break: break-word; }
        .block-shell { background: var(--code-bg); border: 1px solid var(--border); border-radius: 14px; margin: 0 0 0.8em 0; overflow: hidden; }
        .block-header { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 10px 12px; border-bottom: 1px solid var(--border); background: var(--surface); }
        .block-label { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
        .copy-button { appearance: none; border: 1px solid var(--border); background: var(--surface); color: var(--fg); border-radius: 999px; width: 30px; height: 30px; padding: 0; font: inherit; font-size: 14px; font-weight: 700; line-height: 1; display: inline-flex; align-items: center; justify-content: center; }
        .copy-button.copied { background: color-mix(in srgb, var(--success) 18%, var(--surface)); border-color: color-mix(in srgb, var(--success) 45%, var(--border)); color: var(--success); }
        .block-body { padding: 12px; overflow-x: auto; -webkit-overflow-scrolling: touch; }
        .block-body pre { overflow: visible; }
        .block-shell:last-child { margin-bottom: 0; }
        .katex-display { overflow-x: auto; overflow-y: hidden; padding: 0.15em 0; }
        .mermaid-wrap { overflow-x: auto; }
        .mermaid { min-width: fit-content; }
        .mermaid svg { display: block; max-width: 100%; height: auto; }
        .task-list-item { list-style: none; margin-left: -1.4em; }
        .task-list-item input[type=checkbox] { appearance: none; -webkit-appearance: none; width: 18px; height: 18px; border: 1.5px solid var(--border); border-radius: 5px; background: transparent; margin-right: 8px; vertical-align: middle; position: relative; top: -1px; }
        .task-list-item input[type=checkbox]:checked { background: var(--success); border-color: var(--success); }
        .task-list-item input[type=checkbox]:checked::after { content: '\\2713'; color: #fff; font-size: 12px; font-weight: 700; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); line-height: 1; }
      </style>
    </head>
    <body>
      <div id="content"></div>
      <script src="markdown-it.min.js"></script>
      <script src="highlight-common.min.js"></script>
      <script src="katex.min.js"></script>
      <script src="katex-auto-render.min.js"></script>
      <script src="mermaid.min.js"></script>
      <script>
        const md = window.markdownit({
          html: false, linkify: true, breaks: true, typographer: true,
          highlight: (str, lang) => {
            const escaped = md.utils.escapeHtml(str);
            if (lang && window.hljs && hljs.getLanguage(lang)) {
              try {
                const highlighted = hljs.highlight(str, { language: lang, ignoreIllegals: true }).value;
                return '<span class="hljs">' + highlighted + '</span>';
              } catch (_) {}
            }
            return escaped;
          }
        });

        function decodeBase64Unicode(value) {
          const binary = atob(value);
          const bytes = Uint8Array.from(binary, function(c) { return c.charCodeAt(0); });
          return new TextDecoder().decode(bytes);
        }

        function postHeight() {
          var height = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, document.getElementById('content').scrollHeight);
          window.webkit.messageHandlers.resize.postMessage(height);
        }

        function copyIcon() { return '\\u29C9'; }
        function checkIcon() { return '\\u2713'; }

        function makeCopyButton(label, text) {
          var button = document.createElement('button');
          button.className = 'copy-button';
          button.type = 'button';
          button.setAttribute('aria-label', 'Copy ' + label);
          button.innerHTML = '<span>' + copyIcon() + '</span>';
          button.addEventListener('click', function() {
            window.webkit.messageHandlers.copy.postMessage({ text: text });
            button.classList.add('copied');
            button.innerHTML = '<span>' + checkIcon() + '</span>';
            clearTimeout(button._copyResetTimer);
            button._copyResetTimer = setTimeout(function() {
              button.classList.remove('copied');
              button.innerHTML = '<span>' + copyIcon() + '</span>';
            }, 1600);
          });
          return button;
        }

        function makeBlockShell(label, copyText, contentNode) {
          var shell = document.createElement('div');
          shell.className = 'block-shell';
          var header = document.createElement('div');
          header.className = 'block-header';
          var title = document.createElement('div');
          title.className = 'block-label';
          title.textContent = label;
          header.appendChild(title);
          header.appendChild(makeCopyButton(label, copyText));
          var body = document.createElement('div');
          body.className = 'block-body';
          body.appendChild(contentNode);
          shell.appendChild(header);
          shell.appendChild(body);
          return shell;
        }

        function upgradeCheckboxes() {
          var items = Array.from(document.querySelectorAll('#content li'));
          for (var i = 0; i < items.length; i++) {
            var li = items[i];
            var text = li.innerHTML;
            var unchecked = text.match(/^\\[ \\]/);
            var checked = text.match(/^\\[x\\]/i);
            if (unchecked || checked) {
              li.classList.add('task-list-item');
              var isChecked = !!checked;
              li.innerHTML = '<input type="checkbox" ' + (isChecked ? 'checked' : '') + ' disabled>' + text.slice(3).trimStart();
            }
          }
        }

        function upgradeCodeBlocks() {
          var blocks = Array.from(document.querySelectorAll('#content pre code'));
          for (var i = 0; i < blocks.length; i++) {
            var code = blocks[i];
            if (code.classList.contains('language-mermaid') || code.classList.contains('language-math')) continue;
            var pre = code.parentElement;
            if (!pre || pre.tagName !== 'PRE') continue;
            var langClass = Array.from(code.classList).find(function(name) { return name.startsWith('language-'); });
            var lang = langClass ? langClass.replace('language-', '') : 'code';
            pre.replaceWith(makeBlockShell(lang, code.textContent || '', pre));
          }
        }

        function upgradeMathBlocks() {
          var blocks = Array.from(document.querySelectorAll('#content pre code.language-math'));
          for (var i = 0; i < blocks.length; i++) {
            var code = blocks[i];
            var pre = code.parentElement;
            var wrapper = document.createElement('div');
            wrapper.className = 'katex-display';
            try {
              katex.render(code.textContent, wrapper, { displayMode: true, throwOnError: false });
              pre.replaceWith(makeBlockShell('math', code.textContent || '', wrapper));
            } catch (_) {}
          }
        }

        function upgradeMermaidBlocks() {
          var blocks = Array.from(document.querySelectorAll('#content pre code.language-mermaid'));
          if (blocks.length === 0) return;
          for (var i = 0; i < blocks.length; i++) {
            var code = blocks[i];
            var pre = code.parentElement;
            var source = code.textContent || '';
            var wrapper = document.createElement('div');
            wrapper.className = 'mermaid-wrap';
            var target = document.createElement('div');
            target.className = 'mermaid';
            target.textContent = source;
            wrapper.appendChild(target);
            pre.replaceWith(makeBlockShell('mermaid', source, wrapper));
          }
          try {
            mermaid.initialize({ startOnLoad: false, theme: 'dark', securityLevel: 'loose' });
            mermaid.run({ querySelector: '.mermaid' }).then(function() {
              postHeight();
              setTimeout(postHeight, 100);
              setTimeout(postHeight, 400);
            });
          } catch(e) {
            console.error('mermaid error:', e);
          }
        }

        function renderMarkdown(base64) {
          var markdown = decodeBase64Unicode(base64);
          var content = document.getElementById('content');
          content.innerHTML = md.render(markdown);

          upgradeCheckboxes();
          upgradeCodeBlocks();

          if (window.renderMathInElement) {
            try {
              renderMathInElement(content, {
                delimiters: [
                  { left: '\\$\\$', right: '\\$\\$', display: true },
                  { left: '\\$', right: '\\$', display: false },
                  { left: '\\\\(', right: '\\\\)', display: false },
                  { left: '\\\\[', right: '\\\\]', display: true }
                ],
                throwOnError: false
              });
            } catch(e) {}
          }

          upgradeMathBlocks();
          upgradeMermaidBlocks();

          postHeight();
          setTimeout(postHeight, 50);
          setTimeout(postHeight, 200);
        }

        var observer = new MutationObserver(function() { postHeight(); });
        observer.observe(document.getElementById('content'), { childList: true, subtree: true, attributes: true, characterData: true });
        window.addEventListener('load', postHeight);
        window.addEventListener('resize', postHeight);
        window.renderMarkdown = renderMarkdown;
      </script>
    </body>
    </html>
    """

    // MARK: - Coordinator

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

        private func jsonStringLiteral(_ string: String) -> String {
            let data = try? JSONSerialization.data(withJSONObject: [string], options: [])
            let json = String(data: data ?? Data("[\"\"]".utf8), encoding: .utf8) ?? "[\"\"]"
            return String(json.dropFirst().dropLast())
        }
    }
}
