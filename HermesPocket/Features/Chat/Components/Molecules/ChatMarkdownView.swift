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

        if let tempDir = prepareTempDir() {
            view.loadFileURL(tempDir.appendingPathComponent("markdown.html"), allowingReadAccessTo: tempDir)
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

    // MARK: - Temp Directory

    private func prepareTempDir() -> URL? {
        let fm = FileManager.default
        guard let cache = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = cache.appendingPathComponent("hermes-markdown")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let bundleRoot = Bundle.main.bundleURL
        let assets = ["markdown-it.min.js", "highlight-common.min.js", "highlight-github-dark.min.css",
                       "katex.min.js", "katex.min.css", "katex-auto-render.min.js", "mermaid.min.js"]
        for asset in assets {
            let dest = dir.appendingPathComponent(asset)
            let src = bundleRoot.appendingPathComponent(asset)
            if !fm.fileExists(atPath: dest.path), fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dest)
            }
        }

        let htmlPath = dir.appendingPathComponent("markdown.html")
        try? Self.htmlShell.write(to: htmlPath, atomically: true, encoding: .utf8)
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
          --fg: rgba(255,255,255,0.94);
          --muted: rgba(255,255,255,0.55);
          --code-bg: rgba(255,255,255,0.07);
          --inline-code-bg: rgba(255,255,255,0.10);
          --border: rgba(255,255,255,0.10);
          --link: #8ab4ff;
          --surface: rgba(255,255,255,0.05);
          --success: #34c759;
        }
        * { box-sizing: border-box; }
        html, body {
          margin: 0; padding: 0;
          background: transparent; color: var(--fg);
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          font-size: 18px; line-height: 1.5;
          overflow: hidden; word-wrap: break-word;
          -webkit-user-select: text; user-select: text;
        }
        #content { padding: 0; margin: 0; }
        p, ul, ol, blockquote, h1, h2, h3, h4, h5, h6 { margin: 0 0 0.8em 0; }
        p:last-child, ul:last-child, ol:last-child, blockquote:last-child { margin-bottom: 0; }
        h1 { font-size: 1.5em; font-weight: 700; } h2 { font-size: 1.35em; font-weight: 650; } h3 { font-size: 1.2em; font-weight: 600; }
        a { color: var(--link); text-decoration: none; }
        strong { font-weight: 700; } em { font-style: italic; }
        code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.92em; }
        :not(pre) > code { background: var(--inline-code-bg); border-radius: 8px; padding: 0.15em 0.35em; }
        pre { background: transparent; border: 0; border-radius: 0; padding: 0; margin: 0; overflow-x: auto; }
        pre code { background: transparent; padding: 0; font-size: 0.88em; }
        blockquote { border-left: 3px solid var(--quote, rgba(255,255,255,0.16)); margin-left: 0; padding-left: 14px; color: var(--muted); }
        ul, ol { padding-left: 1.4em; } li + li { margin-top: 0.25em; }
        hr { border: 0; border-top: 1px solid var(--border); margin: 1em 0; }
        table { width: 100%; border-collapse: collapse; display: block; overflow-x: auto; }
        th, td { border: 1px solid var(--border); padding: 8px 10px; text-align: left; vertical-align: top; max-width: 220px; white-space: normal; overflow-wrap: anywhere; word-break: break-word; }
        /* Block shell */
        .block-shell { background: var(--code-bg); border: 1px solid var(--border); border-radius: 14px; margin: 0 0 0.8em 0; overflow: hidden; }
        .block-shell:last-child { margin-bottom: 0; }
        .block-header { display: flex; align-items: center; gap: 10px; padding: 10px 14px; }
        .block-label { color: var(--muted); font-size: 11px; font-weight: 600; letter-spacing: 0.05em; text-transform: uppercase; margin-right: auto; }
        .copy-button { appearance: none; -webkit-appearance: none; border: 1px solid var(--border); background: var(--surface); color: var(--fg); border-radius: 999px; width: 28px; height: 28px; min-width: 28px; padding: 0; font: inherit; font-size: 13px; font-weight: 700; line-height: 1; display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0; }
        .copy-button.copied { background: color-mix(in srgb, var(--success) 18%, var(--surface)); border-color: color-mix(in srgb, var(--success) 45%, var(--border)); color: var(--success); }
        .block-body { padding: 14px; overflow-x: auto; -webkit-overflow-scrolling: touch; }
        .block-body pre { overflow: visible; }
        /* Math */
        .katex-display { overflow-x: auto; overflow-y: hidden; padding: 0.15em 0; }
        .katex-display > .katex { text-align: left !important; }
        /* Mermaid */
        .mermaid-wrap { display: flex; justify-content: center; overflow-x: auto; padding: 8px 0; }
        .mermaid { display: inline-block; }
        .mermaid svg { display: block; max-width: 100%; height: auto; }
        /* Task list */
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
        (function() {
          var md = window.markdownit({
            html: false, linkify: true, breaks: true, typographer: true,
            highlight: function(str, lang) {
              if (lang && window.hljs && hljs.getLanguage(lang)) {
                try {
                  return '<span class="hljs">' + hljs.highlight(str, { language: lang, ignoreIllegals: true }).value + '</span>';
                } catch(e) {}
              }
              return md.utils.escapeHtml(str);
            }
          });

          window.decodeBase64 = function(value) {
            var binary = atob(value);
            var bytes = new Uint8Array(binary.length);
            for (var i = 0; i < binary.length; i++) { bytes[i] = binary.charCodeAt(i); }
            return new TextDecoder().decode(bytes);
          };

          function postHeight() {
            var h = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight,
                             document.getElementById('content').scrollHeight);
            window.webkit.messageHandlers.resize.postMessage(h);
          }

          function makeCopyButton(label, text) {
            var btn = document.createElement('button');
            btn.className = 'copy-button';
            btn.type = 'button';
            btn.setAttribute('aria-label', 'Copy ' + label);
            btn.innerHTML = '<span>\\u29C9</span>';
            btn.addEventListener('click', function() {
              window.webkit.messageHandlers.copy.postMessage({ text: text });
              btn.classList.add('copied');
              btn.innerHTML = '<span>\\u2713</span>';
              clearTimeout(btn._timer);
              btn._timer = setTimeout(function() {
                btn.classList.remove('copied');
                btn.innerHTML = '<span>\\u29C9</span>';
              }, 1600);
            });
            return btn;
          }

          function makeBlockShell(label, copyText, bodyNode) {
            var shell = document.createElement('div');
            shell.className = 'block-shell';
            var header = document.createElement('div');
            header.className = 'block-header';
            var btn = makeCopyButton(label, copyText);
            var title = document.createElement('div');
            title.className = 'block-label';
            title.textContent = label;
            header.appendChild(btn);
            header.appendChild(title);
            var body = document.createElement('div');
            body.className = 'block-body';
            body.appendChild(bodyNode);
            shell.appendChild(header);
            shell.appendChild(body);
            return shell;
          }

          function each(list, fn) {
            for (var i = 0; i < list.length; i++) { fn(list[i], i); }
          }

          function toArray(nodeList) {
            var arr = [];
            for (var i = 0; i < nodeList.length; i++) { arr.push(nodeList[i]); }
            return arr;
          }

          function upgradeCheckboxes() {
            each(toArray(document.querySelectorAll('#content li')), function(li) {
              var text = li.innerHTML;
              var m;
              if ((m = text.match(/^\\[ \\]/)) || (m = text.match(/^\\[x\\]/i))) {
                li.classList.add('task-list-item');
                li.innerHTML = '<input type="checkbox" ' + (m[0].toLowerCase() === '[x]' ? 'checked' : '') + ' disabled>' + text.slice(3).replace(/^\\s+/, '');
              }
            });
          }

          function upgradeCodeBlocks() {
            each(toArray(document.querySelectorAll('#content pre code')), function(code) {
              if (/language-mermaid|language-math/.test(code.className)) return;
              var pre = code.parentElement;
              if (!pre || pre.tagName !== 'PRE') return;

              var lang = 'code';
              each(toArray(code.classList), function(cls) {
                if (cls.indexOf('language-') === 0) { lang = cls.replace('language-', ''); }
              });

              pre.replaceWith(makeBlockShell(lang, code.textContent || '', pre));
            });
          }

          function upgradeMathBlocks() {
            each(toArray(document.querySelectorAll('#content pre code.language-math')), function(code) {
              var pre = code.parentElement;
              var wrapper = document.createElement('div');
              wrapper.className = 'katex-display';
              try {
                katex.render(code.textContent, wrapper, { displayMode: true, throwOnError: false });
                pre.replaceWith(makeBlockShell('math', code.textContent || '', wrapper));
              } catch(e) {}
            });
          }

          function upgradeMermaidBlocks() {
            var blocks = toArray(document.querySelectorAll('#content pre code.language-mermaid'));
            if (blocks.length === 0) return;

            each(blocks, function(code) {
              var pre = code.parentElement;
              var source = code.textContent || '';
              var wrapper = document.createElement('div');
              wrapper.className = 'mermaid-wrap';
              var target = document.createElement('div');
              target.className = 'mermaid';
              target.textContent = source;
              wrapper.appendChild(target);
              pre.replaceWith(makeBlockShell('mermaid', source, wrapper));
            });

            try {
              mermaid.initialize({ startOnLoad: false, theme: 'dark', securityLevel: 'loose' });
              mermaid.run({ querySelector: '.mermaid' }).then(function() {
                postHeight();
                setTimeout(postHeight, 100);
                setTimeout(postHeight, 400);
              }).catch(function(e) {
                console.error('mermaid error:', e);
              });
            } catch(e) {
              console.error('mermaid init error:', e);
            }
          }

          window.renderMarkdown = function(base64) {
            var markdown = window.decodeBase64(base64);
            var content = document.getElementById('content');
            content.innerHTML = md.render(markdown);

            upgradeCheckboxes();
            upgradeCodeBlocks();

            // Render math with katex-auto-render
            if (window.renderMathInElement) {
              try {
                renderMathInElement(content, {
                  delimiters: [
                    { left: '\\$\\$', right: '\\$\\$', display: true },
                    { left: '\\$',   right: '\\$',   display: false }
                  ],
                  throwOnError: false
                });
              } catch(e) {}
            }

            // Also handle fenced math code blocks
            upgradeMathBlocks();

            // Mermaid diagrams
            upgradeMermaidBlocks();

            postHeight();
            setTimeout(postHeight, 60);
            setTimeout(postHeight, 250);
          };

          var observer = new MutationObserver(function() { postHeight(); });
          observer.observe(document.getElementById('content'), { childList: true, subtree: true, attributes: true, characterData: true });
          window.addEventListener('load', postHeight);
          window.addEventListener('resize', postHeight);
        })();
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
                    Task { @MainActor in contentHeight = max(24, value) }
                }
            case "copy":
                if let body = message.body as? [String: Any], let text = body["text"] as? String {
                    UIPasteboard.general.string = text
                }
            default: break
            }
        }

        func scheduleRender(markdown: String, isStreaming: Bool) {
            pendingWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in self?.render(markdown: markdown) }
            pendingWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + (isStreaming ? 0.06 : 0), execute: workItem)
        }

        func render(markdown: String) {
            guard let webView else { return }
            let encoded = Data(markdown.utf8).base64EncodedString()
            webView.evaluateJavaScript("window.renderMarkdown(\(jsonLiteral(encoded)));")
        }

        private func jsonLiteral(_ s: String) -> String {
            let d = try? JSONSerialization.data(withJSONObject: [s], options: [])
            let j = String(data: d ?? Data("[\"\"]".utf8), encoding: .utf8) ?? "[\"\"]"
            return String(j.dropFirst().dropLast())
        }
    }
}
