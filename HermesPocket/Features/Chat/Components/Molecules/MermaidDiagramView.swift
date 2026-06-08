import SwiftUI
import WebKit

/// Renders a Mermaid diagram string using WKWebView + Mermaid.js CDN.
///
/// The diagram is embedded in a minimal HTML template that loads mermaid
/// from a CDN, renders the diagram to SVG, and reports the computed height
/// back to SwiftUI via a JavaScript bridge.
struct MermaidDiagramView: View {
    let source: String
    @State private var height: CGFloat = 120

    private let baseHTML: String = {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            background: transparent;
            display: flex;
            justify-content: center;
            padding: 8px;
            font-family: -apple-system, sans-serif;
          }
          #diagram svg { max-width: 100%; height: auto; }
          .error {
            color: #ff6b6b;
            font-family: -apple-system, sans-serif;
            font-size: 13px;
            padding: 16px;
            text-align: center;
            background: rgba(255,255,255,0.04);
            border-radius: 8px;
            border: 1px solid rgba(255,255,255,0.08);
          }
        </style>
        </head>
        <body>
        <div id="diagram" class="mermaid"></div>
        <script>
          mermaid.initialize({ startOnLoad: false, theme: 'dark' });
          async function render() {
            const el = document.getElementById('diagram');
            try {
              const { svg } = await mermaid.render('mermaid-svg', DIAGRAM_SOURCE);
              el.innerHTML = svg;
              const h = el.scrollHeight;
              window.webkit.messageHandlers.height.postMessage(String(h));
            } catch (e) {
              el.innerHTML = '<div class="error">⚠️ ' + e.message.replace(/</g, '&lt;') + '</div>';
              const h = el.scrollHeight;
              window.webkit.messageHandlers.height.postMessage(String(h));
            }
          }
          render();
        </script>
        </body>
        </html>
        """
    }()

    var body: some View {
        GeometryReader { proxy in
            MermaidWebView(
                html: self.makeHTML(width: proxy.size.width),
                height: $height
            )
            .frame(height: max(height, 80))
        }
        .frame(height: max(height, 80))
    }

    private func makeHTML(width: CGFloat) -> String {
        // Escape the diagram source as a JS string literal
        let escaped = source
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "'", with: "\\'")
        return baseHTML
            .replacingOccurrences(of: "DIAGRAM_SOURCE", with: "'\(escaped)'")
    }
}

// MARK: - WebView Coordinator

private struct MermaidWebView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "height")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed — rendered once
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "height")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat

        init(height: Binding<CGFloat>) {
            _height = height
        }

        func userContentController(_ userContentController: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
            guard message.name == "height",
                  let value = message.body as? String,
                  let doubleValue = Double(value) else { return }
            let h = CGFloat(doubleValue)
            DispatchQueue.main.async {
                self.height = h
            }
        }
    }
}

// MARK: - Placeholder

extension MermaidDiagramView {
    /// A small loading placeholder used before the WebView content loads.
    static let placeholder: some View = {
        HStack(spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.caption)
            Text("Loading diagram…")
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.4))
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }()
}
