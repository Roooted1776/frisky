import SwiftUI
import WebKit

/// NFC Preview / NFC Scan — same bundled `tapper.html#d=` shell a stranger
/// gets on band tap (HTML RedMed · 911 · Aid tabs visible). Loads with
/// `?src=app` / `__REDMED_APP_PREVIEW` so SOS does **not** auto-arm (real
/// bracelet opens hosted `/tapper/#d=…` without that flag). Explicit SOS /
/// DeviceMotion / 911 GPS still run in Preview — same as passerby HTML.
/// Does **not** set `html.app-embed` / `__REDMED_APP_EMBED` — that hides the
/// HTML tab bar and is owner RedMed embed only (`PasserbyHTMLShell` with
/// `appEmbed: true`), where native owns 911 / Aid / SOS / GPS.
/// Sets `html.app-preview` and disables WKWebView UIScrollView scrolling so
/// flex tabbar taps work (fixed + dual-scroll ate RedMed · 911 · Aid switches).
struct PasserbyHTMLCardView: View {
    @Environment(\.dismiss) private var dismiss
    /// Raw `#d=` payload (no prefix), or full band URL containing `#d=`.
    let payloadOrURL: String
    /// Owner Linked state — passed into the shell so Preview matches native rules.
    var braceletLinked: Bool = false
    /// Plaintext profile JSON for in-app Preview (skips WebCrypto). Nil for band-style opens.
    var embedProfileJSON: String? = .none

    private var encodedPayload: String? {
        Self.extractPayload(payloadOrURL)
    }

    var body: some View {
        // Same OwnerModalChrome as Help / Edit — even title + side slots.
        VStack(spacing: 0) {
            OwnerModalChrome(
                title: "Preview",
                leadingTitle: "Back",
                leadingAction: { dismiss() }
            )

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

    /// `nonisolated` — strip `#d=` from any thread (NFC callbacks / Task.detached).
    nonisolated static func extractPayload(_ raw: String) -> String? {
        ProfileNFCCodec.extractPayload(fromURLString: raw)
    }

    /// Band write / capacity / NFC Scan — stamps a fresh `updated` time.
    /// `nonisolated` — packs a Sendable chip from `Task.detached` (NFC write / verify).
    nonisolated static func payload(from chip: NFCChipProfile) -> String? {
        guard let url = ProfileNFCCodec.buildURLString(chip: chip) else { return nil }
        return extractPayload(url)
    }

    /// Copies ProfileData into a chip, then packs. ProfileData stays on the isolated caller.
    static func payload(from profile: ProfileData) -> String? {
        payload(from: ProfileNFCCodec.chipProfile(from: profile))
    }

    /// Owner RedMed tab embed — stable pack; caller must cache across `body` passes.
    /// Delegates to `ProfileNFCCodec` so off-main callers never touch this MainActor View.
    nonisolated static func previewPayload(from chip: NFCChipProfile) -> String? {
        ProfileNFCCodec.previewPayload(from: chip)
    }

    /// Copies ProfileData into a chip, then packs. ProfileData stays on the isolated caller.
    static func previewPayload(from profile: ProfileData) -> String? {
        previewPayload(from: ProfileNFCCodec.chipProfile(from: profile))
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
    var embedProfileJSON: String? = .none

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
        if cachedShellHTML != nil {
            _ = ProfileNFCCodec.placeholderPreviewPayload
            return
        }
        guard let url = Bundle.main.url(forResource: "tapper", withExtension: "html"),
              let html = try? String(contentsOf: url, encoding: .utf8) else { return }
        cachedShellFileURL = url
        cachedShellHTML = html
        // Seal empty `#d=` off the unlock path (first access otherwise hits MainActor).
        _ = ProfileNFCCodec.placeholderPreviewPayload
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

// MARK: - WKWebView process warm (Face ID overlap)

/// Pre-creates a cream `WKWebView` and loads bundled `tapper.html` after unlock
/// so the first RedMed paint can skip cold WebKit process + first parse when the
/// pool is ready. Face ID overlap may kick warm after LA presents (~280ms);
/// unlock success must **not** kick warm before `gate = .unlocked` (that stole
/// MainActor during Keychain await). MainActor only — WKWebView is not thread-safe.
///
/// Single-flight warm. Unlock does **not** await this — tabs paint with a
/// placeholder `#d=` + embed JSON; `takeEmbed()` is best-effort on first RedMed
/// mount. `ensureWarmEmbedShell()` remains for callers that need a hard wait.
@MainActor
enum PasserbyWebViewPool {
    private static var warmedEmbed: WKWebView?
    private static var warmTask: Task<WKWebView?, Never>?

    /// Kick a warm without waiting — safe to call repeatedly (single flight).
    static func warmEmbedShell() {
        _ = ensureWarmTask()
    }

    /// Wait until the pooled embed exists (or shell HTML is missing).
    static func ensureWarmEmbedShell() async {
        if warmedEmbed != nil { return }
        _ = await ensureWarmTask().value
    }

    private static func ensureWarmTask() -> Task<WKWebView?, Never> {
        if let warmedEmbed {
            return Task { @MainActor in warmedEmbed }
        }
        if let warmTask { return warmTask }
        // Explicit Task result type — bare `return nil` fails typecheck in this closure.
        let task = Task<WKWebView?, Never> { @MainActor in
            // Shell HTML may still be filling from a detached warm — read through
            // the lock (loads from bundle once if needed).
            let webView = makeConfiguredWebView(navigationDelegate: nil)
            guard let fileURL = PasserbyShellCache.shellFileURL(),
                  var html = PasserbyShellCache.shellHTML() else {
                return .none
            }
            // App-embed chrome only — no PHI. Real profile arrives via JS push or full load.
            let boot = """
            <script>
            window.__REDMED_APP_PREVIEW=1;
            window.__REDMED_APP_EMBED=1;
            window.__REDMED_BRACELET_LINKED=false;
            try{document.documentElement.classList.add('app-embed');}catch(e0){}
            </script>

            """
            if let range = html.range(of: "<head>") {
                html.replaceSubrange(range, with: "<head>\n" + boot)
            } else {
                html = boot + html
            }
            webView.loadHTMLString(html, baseURL: fileURL)
            warmedEmbed = webView
            return webView
        }
        warmTask = task
        Task { @MainActor in
            _ = await task.value
            if warmTask == task { warmTask = nil }
        }
        return task
    }

    /// Owner RedMed tab takes the warmed view once (nil after).
    /// Miss leaves `warmTask` running so a late warm is not discarded mid-flight.
    static func takeEmbed() -> WKWebView? {
        guard let view = warmedEmbed else { return nil }
        warmedEmbed = nil
        warmTask = nil
        return view
    }

    static func makeConfiguredWebView(navigationDelegate: WKNavigationDelegate?) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let cream = UIColor(Color.redmedBg)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = navigationDelegate
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = true
        webView.backgroundColor = cream
        webView.scrollView.isOpaque = true
        webView.scrollView.backgroundColor = cream
        webView.underPageBackgroundColor = cream
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.indicatorStyle = .default
        return webView
    }
}

// MARK: - WKWebView

private struct PasserbyHTMLWebView: UIViewRepresentable {
    let encodedPayload: String
    var braceletLinked: Bool = false
    var appEmbed: Bool = true
    var embedProfileJSON: String? = .none

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.appEmbed = appEmbed
        // Prefer Face ID–warmed embed view — process + HTML parse already done.
        if appEmbed, let pooled = PasserbyWebViewPool.takeEmbed() {
            pooled.navigationDelegate = context.coordinator
            pooled.scrollView.isScrollEnabled = true
            context.coordinator.shellLoaded = true
            context.coordinator.loadedShellKind = "embed"
            // Empty payload → first updateUIView pushes PHI via JS (no second parse).
            context.coordinator.loadedPayload = ""
            context.coordinator.loadedContentKey = ""
            return pooled
        }
        let webView = PasserbyWebViewPool.makeConfiguredWebView(navigationDelegate: context.coordinator)
        // Preview/Scan: document `.app` scrolls; UIScrollView dual-scroll ate tab taps.
        webView.scrollView.isScrollEnabled = appEmbed
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.appEmbed = appEmbed
        // Embed: WKWebView scrolls. Preview/Scan: html.app-preview flex + `.app` scroll.
        webView.scrollView.isScrollEnabled = appEmbed
        let shellKind = appEmbed ? "embed" : "full"
        let contentKey = "\(braceletLinked)|\(embedProfileJSON ?? "")"
        let payloadKey = encodedPayload

        // Keep the document when plaintext embed JSON is present (owner embed + Preview/Scan).
        // AES `#d=` changes every pack (random nonce) — JS push avoids remount, which
        // reset Preview tabs back to RedMed mid-switch.
        if context.coordinator.shellLoaded,
           context.coordinator.loadedShellKind == shellKind,
           let embedProfileJSON, !embedProfileJSON.isEmpty,
           (context.coordinator.loadedContentKey != contentKey
            || context.coordinator.loadedPayload != payloadKey) {
            context.coordinator.loadedContentKey = contentKey
            context.coordinator.loadedPayload = payloadKey
            context.coordinator.loadedKey = "\(payloadKey)|\(contentKey)|\(shellKind)"
            let linkedJS = braceletLinked ? "true" : "false"
            let payloadLit = Self.jsStringLiteral(encodedPayload) ?? "''"
            let js = """
            (function(){
              try {
                window.__REDMED_BRACELET_LINKED=\(linkedJS);
                window.__REDMED_PROFILE=\(embedProfileJSON);
                var d=\(payloadLit);
                try{
                  var base=(location.pathname&&location.pathname!=='blank'&&location.pathname!=='/')
                    ?location.pathname:'tapper.html';
                  history.replaceState(null,'',base+'?src=app#d='+d);
                }catch(e0){}
                if (typeof window.__redmedApplyProfile === 'function') {
                  window.__redmedApplyProfile(window.__REDMED_PROFILE, \(linkedJS));
                }
              } catch (e) {}
            })();
            """
            // Warmed shell may still be parsing — queue until didFinish.
            if webView.isLoading {
                context.coordinator.pendingProfileJS = js
            } else {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
            return
        }

        let loadKey = "\(payloadKey)|\(contentKey)|\(shellKind)"
        guard context.coordinator.loadedKey != loadKey else { return }
        guard let fileURL = PasserbyShellCache.shellFileURL(),
              var html = PasserbyShellCache.shellHTML(),
              let lit = Self.jsStringLiteral(encodedPayload) else { return }
        context.coordinator.loadedKey = loadKey
        context.coordinator.loadedPayload = payloadKey
        context.coordinator.loadedContentKey = contentKey
        context.coordinator.loadedShellKind = shellKind
        context.coordinator.shellLoaded = true
        // Inject before any tapper.html script so decrypt sees #d= and SOS sees app preview.
        // Flag + hash fallback: loadHTMLString can leave location as about:blank where
        // replaceState alone would leave decrypt empty and wrongly auto-arm SOS.
        // Owner embed: `html.app-embed` before first paint. Preview/Scan: full HTML tabs
        // + `html.app-preview` (flex tabbar — fixed + dual-scroll ate taps in WKWebView).
        // `__REDMED_PROFILE` skips WebCrypto when native already has plaintext.
        let linkedJS = braceletLinked ? "true" : "false"
        let embedJS = appEmbed
            ? "window.__REDMED_APP_EMBED=1;try{document.documentElement.classList.add('app-embed');}catch(e0){}"
            : "try{document.documentElement.classList.add('app-preview');}catch(e1){}"
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
        var loadedPayload: String?
        var loadedContentKey: String?
        var loadedShellKind: String?
        var shellLoaded = false
        /// Owner RedMed embed only — Preview / Scan / passerby never open the NFC tab.
        var appEmbed = false
        /// Profile push that arrived before `didFinish` — replay once the document is ready.
        var pendingProfileJS: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let pending = pendingProfileJS {
                pendingProfileJS = nil
                webView.evaluateJavaScript(pending, completionHandler: nil)
            }
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
            case "http", "https", "mailto", "tel":
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
            case "redmed":
                // Owner embed status → NFC tab. Preview / Scan / passerby: drop NFC URLs
                // (bracelet tap shell = RedMed · 911 · Aid only — no NFC · no Edit).
                if Self.isNFCTabURL(url) {
                    if appEmbed {
                        NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                    }
                } else {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
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
                if (url.scheme ?? "").lowercased() == "redmed", Self.isNFCTabURL(url) {
                    if appEmbed {
                        NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                    }
                } else {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            return nil
        }

        /// `redmed://nfc` from owner embed status line (Not linked / Linked bracelet).
        private static func isNFCTabURL(_ url: URL) -> Bool {
            guard (url.scheme ?? "").lowercased() == "redmed" else { return false }
            let host = (url.host ?? "").lowercased()
            if host == "nfc" { return true }
            // Tolerate redmed:///nfc or path-only forms.
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            return path == "nfc"
        }
    }
}
