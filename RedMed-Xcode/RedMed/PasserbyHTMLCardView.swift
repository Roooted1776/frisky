import SwiftUI
import WebKit

/// Owner RedMed tab / Preview / NFC Scan — same bundled `get.html#d=` shell a
/// stranger gets on band tap. Loads with `?src=app` so SOS does **not** auto-arm
/// (real bracelet opens hosted `/get/#d=…` without that flag).
struct PasserbyHTMLCardView: View {
    @Environment(\.dismiss) private var dismiss
    /// Raw `#d=` payload (no prefix), or full band URL containing `#d=`.
    let payloadOrURL: String
    /// Owner Linked state — passed into the shell so app embed matches native rules.
    var braceletLinked: Bool = false

    private var encodedPayload: String? {
        Self.extractPayload(payloadOrURL)
    }

    var body: some View {
        // Same chrome as owner Help/Edit / Aid topic Back — accent red in page-bg bubble.
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ChromeTextAction(title: "Back") { dismiss() }
                Text("Tap card")
                    .font(RedMedChrome.navTitleFont)
                    .foregroundColor(.redmedAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Group {
                if let encodedPayload {
                    PasserbyHTMLShell(
                        encodedPayload: encodedPayload,
                        braceletLinked: braceletLinked
                    )
                } else {
                    Text("Couldn't pack get.html#d= from RedMed.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { RedMedPageBackground() }
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

    /// Band write / capacity / NFC Scan — stamps a fresh `updated` time.
    static func payload(from profile: ProfileData) -> String? {
        guard let url = ProfileNFCCodec.buildURLString(profile: profile) else { return nil }
        return extractPayload(url)
    }

    /// Owner RedMed tab embed — stable pack; caller must cache across `body` passes.
    static func previewPayload(from profile: ProfileData) -> String? {
        guard let url = ProfileNFCCodec.buildPreviewURLString(profile: profile) else { return nil }
        return extractPayload(url)
    }
}

// MARK: - Embedded shell (owner RedMed tab — no Back chrome)

/// Bundled get.html medical panel only (HTML tab bar hidden via `app-embed`).
struct PasserbyHTMLShell: View {
    let encodedPayload: String
    var braceletLinked: Bool = false

    var body: some View {
        PasserbyHTMLWebView(
            encodedPayload: encodedPayload,
            braceletLinked: braceletLinked
        )
        // No `.id` remount — `updateUIView` reloads only when loadKey changes.
        // Ciphertext-based `.id` used to destroy WKWebView on every AES re-seal.
    }
}

// MARK: - WKWebView

private struct PasserbyHTMLWebView: UIViewRepresentable {
    let encodedPayload: String
    var braceletLinked: Bool = false

    /// Disk read once per process — remounts must not re-slurp get.html on main.
    private static var cachedShellHTML: String?
    private static var cachedShellFileURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let cream = UIColor(Color.redmedBg)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        // Opaque cream — translucent WKWebView often flashes system white before CSS.
        webView.isOpaque = true
        webView.backgroundColor = cream
        webView.scrollView.isOpaque = true
        webView.scrollView.backgroundColor = cream
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // Document scroll + visible bar (same idea as Aid `.scrollIndicators(.visible)`).
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.indicatorStyle = .default
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let loadKey = "\(encodedPayload)|\(braceletLinked)"
        guard context.coordinator.loadedKey != loadKey else { return }
        guard let fileURL = Self.shellFileURL(),
              var html = Self.shellHTML(),
              let lit = Self.jsStringLiteral(encodedPayload) else { return }
        context.coordinator.loadedKey = loadKey
        // Inject before any get.html script so decrypt sees #d= and SOS sees app preview.
        // Flag + hash fallback: loadHTMLString can leave location as about:blank where
        // replaceState alone would leave decrypt empty and wrongly auto-arm SOS.
        // `html.app-embed` lands before first paint — body class alone waits on the big IIFE.
        let linkedJS = braceletLinked ? "true" : "false"
        let boot = """
        <script>
        window.__REDMED_APP_PREVIEW=1;
        window.__REDMED_BRACELET_LINKED=\(linkedJS);
        try{document.documentElement.classList.add('app-embed');}catch(e0){}
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

    private static func shellFileURL() -> URL? {
        if let cachedShellFileURL { return cachedShellFileURL }
        let url = Bundle.main.url(forResource: "get", withExtension: "html")
        cachedShellFileURL = url
        return url
    }

    private static func shellHTML() -> String? {
        if let cachedShellHTML { return cachedShellHTML }
        guard let url = shellFileURL(),
              let html = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        cachedShellHTML = html
        return html
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
        var loadedKey: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.flashScrollIndicators()
        }

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
