import SwiftUI
import WebKit

/// Owner Preview / NFC Scan — same `get.html#d=` shell a stranger gets on band tap.
/// Loads the **bundled** passerby page with `?src=app` so SOS does **not** auto-arm
/// (real bracelet opens `https://redmed.pages.dev/get/#d=…` without that flag).
struct PasserbyHTMLCardView: View {
    @Environment(\.dismiss) private var dismiss
    /// Raw `#d=` payload (no prefix), or full band URL containing `#d=`.
    let payloadOrURL: String

    private var encodedPayload: String? {
        Self.extractPayload(payloadOrURL)
    }

    var body: some View {
        NavigationView {
            Group {
                if let encodedPayload {
                    PasserbyHTMLWebView(encodedPayload: encodedPayload)
                } else {
                    Text("Couldn't pack get.html#d= from RedMed.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .padding(24)
                }
            }
            .background(Color.redmedBg.ignoresSafeArea())
            .navigationTitle("Tap card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ChromeTextAction(title: "Back") { dismiss() }
                }
            }
        }
    }

    static func extractPayload(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let range = trimmed.range(of: "#d=") {
            let payload = String(trimmed[range.upperBound...])
            return payload.isEmpty ? nil : payload
        }
        // Already a bare payload.
        return trimmed
    }

    /// Pack live owner profile into the same `#d=` a band write would use.
    static func payload(from profile: ProfileData) -> String? {
        guard let url = ProfileNFCCodec.buildURLString(profile: profile) else { return nil }
        return extractPayload(url)
    }
}

// MARK: - WKWebView

private struct PasserbyHTMLWebView: UIViewRepresentable {
    let encodedPayload: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Color.redmedBg)
        webView.scrollView.backgroundColor = UIColor(Color.redmedBg)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !context.coordinator.didLoad else { return }
        guard let fileURL = Bundle.main.url(forResource: "get", withExtension: "html"),
              var html = try? String(contentsOf: fileURL, encoding: .utf8),
              let lit = Self.jsStringLiteral(encodedPayload) else { return }
        context.coordinator.didLoad = true
        // Inject before any get.html script so decrypt sees #d= and SOS sees app preview.
        // Flag + hash fallback: loadHTMLString can leave location as about:blank where
        // replaceState alone would leave decrypt empty and wrongly auto-arm SOS.
        let boot = """
        <script>
        window.__REDMED_APP_PREVIEW=1;
        (function(){
          var d=\(lit);
          try{
            var base=(location.pathname&&location.pathname!=='blank'&&location.pathname!=='/')
              ?location.pathname:'get.html';
            history.replaceState(null,'',base+'?src=app#d='+d);
          }catch(e){}
          try{ if(!/^#d=/.test(location.hash||'')) location.hash='d='+d; }catch(e2){}
        })();
        </script>

        """
        if let range = html.range(of: "<head>") {
            html.replaceSubrange(range, with: "<head>\n" + boot)
        } else {
            html = boot + html
        }
        // baseURL = the get.html file so relative BrandLogo / sw.js resolve like a real open.
        webView.loadHTMLString(html, baseURL: fileURL)
    }

    /// JSON string literal for safe JS concatenation (bare String is not a valid
    /// `JSONSerialization` top-level object — wrap in an array, then strip `[` `]`).
    private static func jsStringLiteral(_ value: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let wrapped = String(data: data, encoding: .utf8),
              wrapped.count >= 2 else { return nil }
        return String(wrapped.dropFirst().dropLast())
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var didLoad = false

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.isFileURL || url.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            let scheme = (url.scheme ?? "").lowercased()
            switch scheme {
            case "http", "https", "mailto", "tel", "redmed":
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
            default:
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Deny target=_blank / window.open — same posture as LocalWebView.
            if let url = navigationAction.request.url, !url.isFileURL {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return nil
        }
    }
}
