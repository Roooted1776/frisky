import SwiftUI
import WebKit

/// NFC Preview / NFC Scan — same bundled `tapper.html#d=` shell a stranger
/// gets on band tap (HTML RedMed · 911 · Aid tabs visible). Loads with
/// `?src=app` so SOS does **not** auto-arm (real bracelet opens hosted
/// `/tapper/#d=…` without that flag). Owner RedMed tab uses `PasserbyHTMLShell`
/// with `appEmbed: true` instead (native tabs; HTML tab bar hidden).
struct PasserbyHTMLCardView: View {
    @Environment(\.dismiss) private var dismiss
    /// Raw `#d=` payload (no prefix), or full band URL containing `#d=`.
    let payloadOrURL: String
    /// Owner Linked state — passed into the shell so Preview matches native rules.
    var braceletLinked: Bool = false
    /// Plaintext profile JSON for in-app Preview (skips WebCrypto). Nil for band-style opens.
    var embedProfileJSON: String? = nil

    private var encodedPayload: String? {
        Self.extractPayload(payloadOrURL)
    }

    var body: some View {
        // Same chrome as owner Help/Edit / Aid topic Back — accent red text, no chip box.
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ChromeTextAction(title: "Back") { dismiss() }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Group {
                if let encodedPayload {
                    PasserbyHTMLShell(
                        encodedPayload: encodedPayload,
                        braceletLinked: braceletLinked,
                        // Full passerby chrome — what a band tap opens (not owner embed).
                        appEmbed: false,
                        embedProfileJSON: embedProfileJSON
                    )
                } else {
                    Text("Couldn't pack tapper.html#d= from RedMed.")
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

    /// Slurp bundled `tapper.html` off the hot path so first RedMed / Preview paint skips disk.
    /// `nonisolated` — callers warm from `Task.detached` during unlock / cold start.
    nonisolated static func warmShellCache() {
        PasserbyShellCache.warm()
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

/// Bundled `tapper.html`. Owner RedMed tab sets `appEmbed` so the HTML tab bar
/// hides (native tabs own 911 / Aid). Preview / Scan leave `appEmbed` false.
struct PasserbyHTMLShell: View {
    let encodedPayload: String
    var braceletLinked: Bool = false
    var appEmbed: Bool = true
    /// Optional plaintext JSON for `window.__REDMED_PROFILE` (skips in-app WebCrypto).
    var embedProfileJSON: String? = nil

    var body: some View {
        PasserbyHTMLWebView(
            encodedPayload: encodedPayload,
            braceletLinked: braceletLinked,
            appEmbed: appEmbed,
            embedProfileJSON: embedProfileJSON
        )
        // No `.id` remount — `updateUIView` reloads only when loadKey changes.
        // Ciphertext-based `.id` used to destroy WKWebView on every AES re-seal.
    }

    /// Warm bundled tapper.html into memory during Face ID (no PHI).
    /// Routes to the nonisolated process cache (MainActor-safe from any caller).
    static func warmShellCache() {
        PasserbyHTMLCardView.warmShellCache()
    }
}

// MARK: - Shell HTML cache (nonisolated — View / UIViewRepresentable are MainActor)

/// Process-wide bundled `tapper.html` cache. Lock-guarded so unlock / cold start
/// can warm off the main thread without Swift concurrency isolation errors.
private enum PasserbyShellCache {
    private static var cachedShellHTML: String?
    private static var cachedShellFileURL: URL?
    private static let cacheLock = NSLock()

    static func warm() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if cachedShellHTML != nil { return }
        guard let url = Bundle.main.url(forResource: "tapper", withExtension: "html"),
              let html = try? String(contentsOf: url, encoding: .utf8) else { return }
        cachedShellFileURL = url
        cachedShellHTML = html
    }

    static func shellFileURL() -> URL? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedShellFileURL { return cachedShellFileURL }
        let url = Bundle.main.url(forResource: "tapper", withExtension: "html")
        cachedShellFileURL = url
        return url
    }

    static func shellHTML() -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedShellHTML { return cachedShellHTML }
        guard let url = Bundle.main.url(forResource: "tapper", withExtension: "html")
                ?? cachedShellFileURL,
              let html = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        cachedShellFileURL = url
        cachedShellHTML = html
        return html
    }
}

// MARK: - WKWebView

private struct PasserbyHTMLWebView: UIViewRepresentable {
    let encodedPayload: String
    var braceletLinked: Bool = false
    var appEmbed: Bool = true
    var embedProfileJSON: String? = nil

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
        // Overscroll / bounce uses this — without it iOS flashes system white.
        webView.underPageBackgroundColor = cream
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
        let loadKey = "\(encodedPayload)|\(braceletLinked)|\(appEmbed)|\(embedProfileJSON ?? "")"
        guard context.coordinator.loadedKey != loadKey else { return }
        guard let fileURL = PasserbyShellCache.shellFileURL(),
              var html = PasserbyShellCache.shellHTML(),
              let lit = Self.jsStringLiteral(encodedPayload) else { return }
        context.coordinator.loadedKey = loadKey
        // Inject before any tapper.html script so decrypt sees #d= and SOS sees app preview.
        // Flag + hash fallback: loadHTMLString can leave location as about:blank where
        // replaceState alone would leave decrypt empty and wrongly auto-arm SOS.
        // Owner embed: `html.app-embed` before first paint. Preview/Scan: full HTML tabs.
        // `__REDMED_PROFILE` skips WebCrypto when native already has plaintext.
        let linkedJS = braceletLinked ? "true" : "false"
        let embedJS = appEmbed
            ? "try{document.documentElement.classList.add('app-embed');}catch(e0){}"
            : ""
        let profileJS: String
        if let embedProfileJSON, !embedProfileJSON.isEmpty {
            profileJS = "window.__REDMED_PROFILE=\(embedProfileJSON);"
        } else {
            profileJS = ""
        }
        let boot = """
        <script>
        window.__REDMED_APP_PREVIEW=1;
        window.__REDMED_BRACELET_LINKED=\(linkedJS);
        \(profileJS)
        \(embedJS)
        (function(){
          var d=\(lit);
          try{
            var base=(location.pathname&&location.pathname!=='blank'&&location.pathname!=='/')
              ?location.pathname:'tapper.html';
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
        // baseURL = the tapper.html file so relative BrandLogo / sw.js resolve like a real open.
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
