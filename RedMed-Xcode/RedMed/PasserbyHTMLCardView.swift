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
        // Inject before any get.html script so decrypt sees #d= and SOS sees ?src=app.
        let boot = "<script>try{history.replaceState(null,'','?src=app#d='+\(lit));}catch(e){}</script>\n"
        if let range = html.range(of: "<head>") {
            html.replaceSubrange(range, with: "<head>\n" + boot)
        } else {
            html = boot + html
        }
        let dir = fileURL.deletingLastPathComponent()
        webView.loadHTMLString(html, baseURL: dir)
    }

    private static func jsStringLiteral(_ value: String) -> String? {
        guard JSONSerialization.isValidJSONObject([value]),
              let data = try? JSONSerialization.data(withJSONObject: value, options: []),
              let lit = String(data: data, encoding: .utf8) else { return nil }
        return lit
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
    }
}
