import SwiftUI
import WebKit

/// Owner-only, shown once ever before the *first* NFC Preview/Scan — a plain
/// heads-up that this view renders exactly what a stranger's tap unlocks (no
/// Face ID, no login). Never applies to a real bracelet tap: that opens the
/// hosted `/tapper/#d=…` page directly in Safari and never touches this file
/// or any Swift code, so the acknowledgment can't add a step to the actual
/// emergency path.
enum NFCPreviewAcknowledgment {
    private static let acknowledgedKey = "redmed.nfcPreviewAcknowledged"

    static var hasAcknowledged: Bool {
        UserDefaults.standard.bool(forKey: acknowledgedKey)
    }

    static func recordAcknowledged() {
        UserDefaults.standard.set(true, forKey: acknowledgedKey)
    }
}

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
/// Never calls `BiometricAuth` — passerby / Preview tap-to-view stays ungated.
/// Nothing covers this shell (no privacy veil, no Face ID, no native overlay)
/// — the one-time `NFCPreviewAcknowledgment` screen below is owner-only
/// framing shown before the shell mounts, not a gate on the shell itself.
struct PasserbyHTMLCardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = NFCPreviewAcknowledgment.hasAcknowledged
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
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ChromeTextAction(title: "Back", weight: .bold) {
                    TapCardPresentation.setVisible(false)
                    dismiss()
                }
                Spacer(minLength: 0)
                OwnerHelpButton()
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Group {
                if !acknowledged {
                    acknowledgmentGate
                } else if let encodedPayload {
                    PasserbyHTMLShell(
                        encodedPayload: encodedPayload,
                        braceletLinked: braceletLinked,
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
        .onAppear { TapCardPresentation.setVisible(true) }
        .onDisappear { TapCardPresentation.setVisible(false) }
        .environment(\.isScannerSession, true)
        .presentsOwnerHelp()
    }

    private var acknowledgmentGate: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Before you preview")
                    .font(.system(size: 20, weight: .bold))
                    .kerning(-0.4)
                    .foregroundColor(.redmedDark)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                Text("This shows exactly what a stranger sees the instant they tap your bracelet — no Face ID, no login, no lock screen. Only what you've filled in on RedMed, 911, and Aid is visible.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .redmedBox()

                PrimaryButton(title: "Continue") {
                    NFCPreviewAcknowledgment.recordAcknowledged()
                    acknowledged = true
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
        }
    }

    nonisolated static func warmShellCache() {
        PasserbyShellCache.warm()
    }

    /// Cold launch calls this from several independent spots (app `.task`,
    /// `OwnerAppLock.onAppear`, `startUnlockPipeline`) so at least one of
    /// them fires regardless of view-lifecycle timing. `PasserbyShellCache.warm()`
    /// itself is idempotent, but each caller was still spawning its own
    /// `Task.detached` — up to three separate GCD thread-pool entries all
    /// racing the same `NSLock` in the same instant, alongside the Face ID
    /// sheet and Keychain prefetch. This collapses that to a single
    /// scheduled task so cold-launch CPU load doesn't spike from redundant
    /// scheduling.
    nonisolated static func scheduleShellWarmOnce() {
        PasserbyShellWarmScheduler.scheduleOnce()
    }

    nonisolated static func extractPayload(_ raw: String) -> String? {
        ProfileNFCCodec.extractPayload(fromURLString: raw)
    }

    nonisolated static func payload(from chip: NFCChipProfile) -> String? {
        guard let url = ProfileNFCCodec.buildURLString(chip: chip) else { return nil }
        return extractPayload(url)
    }

    static func payload(from profile: ProfileData) -> String? {
        payload(from: ProfileNFCCodec.chipProfile(from: profile))
    }

    nonisolated static func previewPayload(from chip: NFCChipProfile) -> String? {
        ProfileNFCCodec.previewPayload(from: chip)
    }

    static func previewPayload(from profile: ProfileData) -> String? {
        previewPayload(from: ProfileNFCCodec.chipProfile(from: profile))
    }
}

enum TapCardPresentation {
    private static let lock = NSLock()
    private static var visible = false

    static var isVisible: Bool {
        lock.lock()
        defer { lock.unlock() }
        return visible
    }

    static func setVisible(_ visible: Bool) {
        lock.lock()
        let changed = self.visible != visible
        self.visible = visible
        lock.unlock()
        guard changed else { return }
        NotificationCenter.default.post(name: .redMedTapCardPresentationDidChange, object: nil)
    }
}

struct PasserbyHTMLShell: View {
    let encodedPayload: String
    var braceletLinked: Bool = false
    var appEmbed: Bool = true
    var embedProfileJSON: String? = .none
    var pageVisible: Bool = true

    var body: some View {
        PasserbyHTMLWebView(
            encodedPayload: encodedPayload,
            braceletLinked: braceletLinked,
            appEmbed: appEmbed,
            embedProfileJSON: embedProfileJSON,
            pageVisible: pageVisible
        )
    }

    static func warmShellCache() {
        PasserbyHTMLCardView.warmShellCache()
    }
}

private enum PasserbyShellWarmScheduler {
    private static let lock = NSLock()
    private static var scheduled = false

    /// Reset per lock cycle isn't needed — the shell string cache itself
    /// never needs re-warming after the first successful read, so once
    /// scheduled for this process, later callers are no-ops.
    nonisolated static func scheduleOnce() {
        lock.lock()
        let alreadyScheduled = scheduled
        scheduled = true
        lock.unlock()
        guard !alreadyScheduled else { return }
        Task.detached(priority: .utility) {
            PasserbyHTMLCardView.warmShellCache()
        }
    }
}

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
        _ = ProfileNFCCodec.placeholderPreviewPayload
    }

    /// Returns the cached shell without touching disk. Nil until `warm()` (or a
    /// prior `shellFileURL()`/`shellHTML()` call) has populated the cache — callers
    /// on the main thread should prefer this over `shellFileURL()`/`shellHTML()`
    /// to avoid a synchronous file read during a SwiftUI view update.
    static func peek() -> (url: URL, html: String)? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let url = cachedShellFileURL, let html = cachedShellHTML else { return nil }
        return (url, html)
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

@MainActor
enum PasserbyWebViewPool {
    /// Warm-webview state for one shell kind (embed vs. full/preview). A
    /// class so two independent slots can share the same warm/take logic
    /// without one kind's webview ever being confused for the other's.
    private final class Slot {
        var warmed: WKWebView?
        var warmTask: Task<WKWebView?, Never>?
        var warming: WKWebView?
    }

    private static let embedSlot = Slot()
    /// NFC Scan / Preview tap card (`appEmbed: false`) — a separate WKWebView
    /// from `embedSlot` so warming it can never race the RedMed tab's own
    /// first paint (that race is why embed pre-warm was disabled — #see
    /// "Faster post-auth paint" history).
    private static let fullSlot = Slot()

    static func warmEmbedShell() {
        _ = ensureWarmTask(slot: embedSlot, embed: true)
    }

    /// Pre-warms a spare non-embed shell so the first NFC Scan / Preview tap
    /// doesn't pay full WKWebView cold-start cost. Call only well after the
    /// RedMed tab has painted (e.g. shortly after unlock) — never during
    /// Face ID or on the same turn as the RedMed tab's own load.
    static func warmFullShell() {
        _ = ensureWarmTask(slot: fullSlot, embed: false)
    }

    static func cancelWarm() {
        cancelWarm(slot: embedSlot)
        cancelWarm(slot: fullSlot)
    }

    private static func cancelWarm(slot: Slot) {
        guard slot.warmed == nil else {
            slot.warmTask = nil
            return
        }
        slot.warmTask?.cancel()
        slot.warmTask = nil
        if let warming = slot.warming {
            warming.stopLoading()
            warming.navigationDelegate = nil
            slot.warming = nil
        }
    }

    static func ensureWarmEmbedShell() async {
        if embedSlot.warmed != nil { return }
        _ = await ensureWarmTask(slot: embedSlot, embed: true).value
    }

    private static func ensureWarmTask(slot: Slot, embed: Bool) -> Task<WKWebView?, Never> {
        if let warmed = slot.warmed {
            return Task { @MainActor in warmed }
        }
        if let warmTask = slot.warmTask { return warmTask }
        let task = Task<WKWebView?, Never> { @MainActor in
            if Task.isCancelled { return .none }

            let prepared: (String, String)? = await Task.detached(priority: .userInitiated) {
                guard let fileURL = PasserbyShellCache.shellFileURL(),
                      var html = PasserbyShellCache.shellHTML() else {
                    return nil
                }

                let boot = embed
                    ? """
                      <style>html,body{background:#fff7f7!important;margin:0}</style>
                      <script>
                      window.__REDMED_APP_PREVIEW=1;
                      window.__REDMED_APP_EMBED=1;
                      window.__REDMED_BRACELET_LINKED=false;
                      try{document.documentElement.classList.add('app-embed');}catch(e0){}
                      </script>

                      """
                    : """
                      <style>html,body{background:#fff7f7!important;margin:0}</style>
                      <script>
                      window.__REDMED_APP_PREVIEW=1;
                      window.__REDMED_BRACELET_LINKED=false;
                      try{document.documentElement.classList.add('app-preview');}catch(e1){}
                      </script>

                      """
                if let range = html.range(of: "<head>") {
                    html.replaceSubrange(range, with: "<head>\n" + boot)
                } else {
                    html = boot + html
                }
                return (fileURL.path, html)
            }.value

            guard let (filePath, html) = prepared else { return .none }
            if Task.isCancelled { return .none }

            let webView = makeConfiguredWebView(navigationDelegate: nil)
            slot.warming = webView
            webView.loadHTMLString(html, baseURL: URL(fileURLWithPath: filePath))
            if Task.isCancelled {
                webView.stopLoading()
                webView.navigationDelegate = nil
                if slot.warming === webView { slot.warming = nil }
                return .none
            }
            slot.warming = nil
            slot.warmed = webView
            return webView
        }
        slot.warmTask = task
        Task { @MainActor in
            _ = await task.value
            if slot.warmTask == task { slot.warmTask = nil }
        }
        return task
    }

    /// Owner RedMed tab takes a *finished* warmed view once (nil after).
    /// Mid-load handoff can miss didFinish after delegate attach and leave
    /// RedMed permanently cream — only return when parse has a real document.
    static func takeEmbed() -> WKWebView? { take(slot: embedSlot) }

    /// NFC Scan / Preview takes a *finished* warmed view once (nil after).
    /// Same finished-only guard as `takeEmbed` — a mid-load handoff would
    /// leave the tap card blank instead of showing the RedMed·911·Aid shell.
    static func takeFull() -> WKWebView? { take(slot: fullSlot) }

    private static func take(slot: Slot) -> WKWebView? {
        guard let view = slot.warmed else { return nil }
        guard !view.isLoading, view.url != nil else {
            // Still parsing — first paint uses a fresh webview with a live delegate.
            return nil
        }
        slot.warmed = nil
        slot.warmTask = nil
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

private struct PasserbyHTMLWebView: UIViewRepresentable {
    let encodedPayload: String
    var braceletLinked: Bool = false
    var appEmbed: Bool = true
    var embedProfileJSON: String? = .none
    var pageVisible: Bool = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.appEmbed = appEmbed
        // Prefer a *finished* Face ID–warmed embed. Mid-load handoff can miss
        // didFinish after delegate attach (warm used navigationDelegate: nil) and
        // leave RedMed permanently cream — the default first tab never flips
        // pageVisible to trigger recoverIfNeeded.
        if appEmbed, let pooled = PasserbyWebViewPool.takeEmbed() {
            pooled.navigationDelegate = context.coordinator
            pooled.scrollView.isScrollEnabled = true
            context.coordinator.usingPooledShell = true
            context.coordinator.loadedShellKind = "embed"
            context.coordinator.loadedPayload = ""
            context.coordinator.loadedContentKey = ""
            context.coordinator.shellLoaded = false
            return pooled
        }
        // Same finished-only handoff for NFC Scan / Preview — a distinct
        // pool from the embed one above, so it never competes with RedMed
        // tab's own load for first paint.
        if !appEmbed, let pooled = PasserbyWebViewPool.takeFull() {
            pooled.navigationDelegate = context.coordinator
            pooled.scrollView.isScrollEnabled = false
            context.coordinator.usingPooledShell = true
            context.coordinator.loadedShellKind = "full"
            context.coordinator.loadedPayload = ""
            context.coordinator.loadedContentKey = ""
            context.coordinator.shellLoaded = false
            return pooled
        }
        let webView = PasserbyWebViewPool.makeConfiguredWebView(navigationDelegate: context.coordinator)
        webView.scrollView.isScrollEnabled = appEmbed
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.appEmbed = appEmbed
        webView.scrollView.isScrollEnabled = appEmbed
        let shellKind = appEmbed ? "embed" : "full"
        let contentKey = "\(braceletLinked)|\(embedProfileJSON ?? "")"
        let payloadKey = encodedPayload

        let coordinator = context.coordinator
        coordinator.forceReload = { [weak coordinator, encodedPayload, braceletLinked, appEmbed, embedProfileJSON] wv in
            guard let coordinator else { return }
            Self.performFullLoad(
                into: wv,
                coordinator: coordinator,
                encodedPayload: encodedPayload,
                braceletLinked: braceletLinked,
                appEmbed: appEmbed,
                embedProfileJSON: embedProfileJSON
            )
        }

        if pageVisible {
            if !coordinator.pageVisible {
                coordinator.pageVisible = true
                coordinator.recoverIfNeeded(webView)
            }
        } else {
            coordinator.pageVisible = false
        }

        let loadKey = "\(payloadKey)|\(contentKey)|\(shellKind)"

        if coordinator.usingPooledShell {
            coordinator.usingPooledShell = false
            coordinator.adoptLoadIdentity(
                loadKey: loadKey,
                payloadKey: payloadKey,
                contentKey: contentKey,
                shellKind: shellKind
            )
            let js: String? = {
                guard let embedProfileJSON, !embedProfileJSON.isEmpty else { return nil }
                return Self.profilePushJS(
                    encodedPayload: encodedPayload,
                    braceletLinked: braceletLinked,
                    embedProfileJSON: embedProfileJSON
                )
            }()
            coordinator.pendingProfileJS = js
            // Finished pool only (takeEmbed guards) — still probe + deadline.
            coordinator.confirmPooledShellLoaded(webView)
            coordinator.scheduleLoadDeadline(for: webView)
            return
        }

        if coordinator.shellLoaded,
           coordinator.loadedShellKind == shellKind,
           let embedProfileJSON, !embedProfileJSON.isEmpty,
           (coordinator.loadedContentKey != contentKey
            || coordinator.loadedPayload != payloadKey) {
            coordinator.adoptLoadIdentity(
                loadKey: loadKey,
                payloadKey: payloadKey,
                contentKey: contentKey,
                shellKind: shellKind
            )
            let js = Self.profilePushJS(
                encodedPayload: encodedPayload,
                braceletLinked: braceletLinked,
                embedProfileJSON: embedProfileJSON
            )
            if webView.isLoading {
                coordinator.pendingProfileJS = js
            } else {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
            return
        }

        guard coordinator.loadedKey != loadKey else {
            if !coordinator.shellLoaded,
               let embedProfileJSON, !embedProfileJSON.isEmpty {
                coordinator.pendingProfileJS = Self.profilePushJS(
                    encodedPayload: encodedPayload,
                    braceletLinked: braceletLinked,
                    embedProfileJSON: embedProfileJSON
                )
            }
            return
        }
        Self.performFullLoad(
            into: webView,
            coordinator: coordinator,
            encodedPayload: encodedPayload,
            braceletLinked: braceletLinked,
            appEmbed: appEmbed,
            embedProfileJSON: embedProfileJSON
        )
    }

    private static func bootedShellHTML(
        shellHTML: String,
        encodedPayload: String,
        braceletLinked: Bool,
        appEmbed: Bool,
        embedProfileJSON: String?
    ) -> String? {
        guard let lit = jsStringLiteral(encodedPayload) else { return nil }
        var html = shellHTML
        let linkedJS = braceletLinked ? "true" : "false"
        let embedJS = appEmbed
            ? "window.__REDMED_APP_EMBED=1;try{document.documentElement.classList.add('app-embed');}catch(e0){}"
            : "try{document.documentElement.classList.add('app-preview');}catch(e1){}"
        let profileJS: String
        if let embedProfileJSON, !embedProfileJSON.isEmpty {
            profileJS = "window.__redmedNativeProfile=true;window.__REDMED_PROFILE=\(Self.htmlSafeJSON(embedProfileJSON));"
        } else {
            profileJS = ""
        }
        let boot = """
        <style>html,body{background:#fff7f7!important;margin:0}</style>
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
        return html
    }

    /// Builds the boot-wrapped shell HTML and loads it. When the shell string is
    /// already cached in memory (the common case — `PasserbyShellCache.warm()`
    /// runs at cold launch) this happens synchronously on this same SwiftUI
    /// update pass. On a cache miss the disk read + decode is hopped to a
    /// background task instead of blocking `updateUIView`'s main-thread pass —
    /// `loadedKey` is re-checked before the deferred load fires so a newer call
    /// (a fresh `payloadOrURL` / visibility flip) that landed in the meantime
    /// wins instead of the stale one.
    private static func performFullLoad(
        into webView: WKWebView,
        coordinator: Coordinator,
        encodedPayload: String,
        braceletLinked: Bool,
        appEmbed: Bool,
        embedProfileJSON: String?
    ) {
        let shellKind = appEmbed ? "embed" : "full"
        let contentKey = "\(braceletLinked)|\(embedProfileJSON ?? "")"
        let payloadKey = encodedPayload
        let loadKey = "\(payloadKey)|\(contentKey)|\(shellKind)"
        coordinator.adoptLoadIdentity(
            loadKey: loadKey,
            payloadKey: payloadKey,
            contentKey: contentKey,
            shellKind: shellKind
        )
        coordinator.shellLoaded = false
        coordinator.loadAttempts += 1

        if let cached = PasserbyShellCache.peek() {
            guard let html = bootedShellHTML(
                shellHTML: cached.html,
                encodedPayload: encodedPayload,
                braceletLinked: braceletLinked,
                appEmbed: appEmbed,
                embedProfileJSON: embedProfileJSON
            ) else { return }
            webView.loadHTMLString(html, baseURL: cached.url)
            coordinator.scheduleLoadDeadline(for: webView)
            return
        }

        Task { @MainActor [weak webView, weak coordinator] in
            let prepared: (URL, String)? = await Task.detached(priority: .userInitiated) {
                guard let fileURL = PasserbyShellCache.shellFileURL(),
                      let shellHTML = PasserbyShellCache.shellHTML() else { return nil }
                return (fileURL, shellHTML)
            }.value
            guard let webView, let coordinator, coordinator.loadedKey == loadKey,
                  let (fileURL, shellHTML) = prepared,
                  let html = bootedShellHTML(
                      shellHTML: shellHTML,
                      encodedPayload: encodedPayload,
                      braceletLinked: braceletLinked,
                      appEmbed: appEmbed,
                      embedProfileJSON: embedProfileJSON
                  )
            else { return }
            webView.loadHTMLString(html, baseURL: fileURL)
            coordinator.scheduleLoadDeadline(for: webView)
        }
    }

    private static func profilePushJS(
        encodedPayload: String,
        braceletLinked: Bool,
        embedProfileJSON: String
    ) -> String {
        let linkedJS = braceletLinked ? "true" : "false"
        let payloadLit = jsStringLiteral(encodedPayload) ?? "''"
        return """
        (function(){
          try {
            window.__redmedNativeProfile=true;
            window.__REDMED_BRACELET_LINKED=\(linkedJS);
            window.__REDMED_PROFILE=\(htmlSafeJSON(embedProfileJSON));
            var d=\(payloadLit);
            try{
              var base=(location.pathname&&location.pathname!=='blank'&&location.pathname!=='/')
                ?location.pathname:'tapper.html';
              history.replaceState(null,'',base+'?src=app#d='+d);
            }catch(e0){}
            var n=0;
            (function tick(){
              if (typeof window.__redmedApplyProfile === 'function') {
                window.__redmedApplyProfile(window.__REDMED_PROFILE, \(linkedJS));
                return;
              }
              if (++n < 40) setTimeout(tick, 25);
            })();
          } catch (e) {}
        })();
        """
    }

    /// JSON that is safe to interpolate into HTML `<script>` (and into
    /// `evaluateJavaScript`). Escapes `<` so `</script>` in a PHI field
    /// cannot break out of the boot script tag.
    private static func htmlSafeJSON(_ json: String) -> String {
        json
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

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
        var usingPooledShell = false
        var appEmbed = false
        var pendingProfileJS: String?
        var pageVisible = true
        var loadAttempts = 0
        var isRecovering = false
        var forceReload: ((WKWebView) -> Void)?
        /// Bounded recovery if didFinish / probe never completes (blank RedMed).
        private var loadDeadlineTask: Task<Void, Never>?

        func adoptLoadIdentity(
            loadKey: String,
            payloadKey: String,
            contentKey: String,
            shellKind: String
        ) {
            loadedKey = loadKey
            loadedPayload = payloadKey
            loadedContentKey = contentKey
            loadedShellKind = shellKind
        }

        func cancelLoadDeadline() {
            loadDeadlineTask?.cancel()
            loadDeadlineTask = nil
        }

        /// If shellLoaded is still false after 2.5s, force recovery (capped by loadAttempts).
        func scheduleLoadDeadline(for webView: WKWebView) {
            cancelLoadDeadline()
            loadDeadlineTask = Task { @MainActor [weak self, weak webView] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard let self, let webView, !Task.isCancelled else { return }
                guard !self.shellLoaded else { return }
                self.scheduleRecovery(into: webView)
            }
        }

        func recoverIfNeeded(_ webView: WKWebView) {
            if webView.isLoading || isRecovering || loadAttempts >= 2 { return }
            if webView.url == nil {
                scheduleRecovery(into: webView)
                return
            }
            webView.evaluateJavaScript(
                "(document.body && document.body.childElementCount > 0) ? 1 : 0"
            ) { [weak self] result, error in
                guard let self else { return }
                let ok: Bool
                if let n = result as? NSNumber {
                    ok = n.intValue > 0
                } else if let n = result as? Int {
                    ok = n > 0
                } else if let b = result as? Bool {
                    ok = b
                } else {
                    ok = false
                }
                if error != nil || !ok {
                    self.scheduleRecovery(into: webView)
                }
            }
        }

        func confirmPooledShellLoaded(_ webView: WKWebView) {
            guard webView.url != nil else {
                scheduleRecovery(into: webView)
                return
            }
            webView.evaluateJavaScript(
                "(document.body && document.body.childElementCount > 0) ? 1 : 0"
            ) { [weak self, weak webView] result, error in
                guard let self, let webView else { return }
                let ok: Bool
                if let n = result as? NSNumber {
                    ok = n.intValue > 0
                } else if let n = result as? Int {
                    ok = n > 0
                } else if let b = result as? Bool {
                    ok = b
                } else {
                    ok = false
                }
                guard error == nil, ok else {
                    self.scheduleRecovery(into: webView)
                    return
                }
                self.cancelLoadDeadline()
                self.shellLoaded = true
                if let pending = self.pendingProfileJS {
                    self.pendingProfileJS = nil
                    webView.evaluateJavaScript(pending, completionHandler: nil)
                }
            }
        }

        private func scheduleRecovery(into webView: WKWebView) {
            cancelLoadDeadline()
            guard !isRecovering, loadAttempts < 2 else { return }
            isRecovering = true
            loadedKey = nil
            shellLoaded = false
            DispatchQueue.main.async { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.isRecovering = false
                self.forceReload?(webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            cancelLoadDeadline()
            shellLoaded = true
            loadAttempts = 0
            if let pending = pendingProfileJS {
                pendingProfileJS = nil
                webView.evaluateJavaScript(pending, completionHandler: nil)
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            scheduleRecovery(into: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            retryLoad(webView, error: error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            retryLoad(webView, error: error)
        }

        private func retryLoad(_ webView: WKWebView, error: Error) {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return }
            guard loadAttempts < 2 else { return }
            scheduleRecovery(into: webView)
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

        private static func isNFCTabURL(_ url: URL) -> Bool {
            guard (url.scheme ?? "").lowercased() == "redmed" else { return false }
            let host = (url.host ?? "").lowercased()
            if host == "nfc" { return true }
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            return path == "nfc"
        }
    }
}
