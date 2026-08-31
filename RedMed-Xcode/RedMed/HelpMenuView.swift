import SwiftUI
import WebKit
import UIKit

/// Bundled owner Help: one HTML file, four policy anchors. Offline. No network.
enum HelpDocument {
    static let bundledFile = "Help"

    enum Policy: String, CaseIterable, Identifiable {
        case privacy
        case security
        case terms
        case medicalDisclaimer

        var id: String { rawValue }

        var title: String {
            switch self {
            case .privacy: return "Privacy"
            case .security: return "Security"
            case .terms: return "Terms"
            case .medicalDisclaimer: return "Medical Disclaimer"
            }
        }

        /// Same marks as Help.html nav + page titles.
        var emoji: String {
            switch self {
            case .privacy: return "🔒"
            case .security: return "🛡"
            case .terms: return "📜"
            case .medicalDisclaimer: return "⚕️"
            }
        }

        var fragment: String {
            switch self {
            case .medicalDisclaimer: return "medical-disclaimer"
            default: return rawValue
            }
        }
    }
}

// MARK: - WebView wrapper (bundled Help / policy HTML only)
struct LocalWebView: UIViewRepresentable {
    let filename: String
    var fragment: String? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Policies are static bundle HTML — no app ↔ page script bridge.
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let cream = UIColor(Color.redmedBg)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        // Same opaque cream as passerby shell — avoid system white flash.
        webView.isOpaque = true
        webView.backgroundColor = cream
        webView.scrollView.isOpaque = true
        webView.scrollView.backgroundColor = cream
        webView.underPageBackgroundColor = cream
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let key = "\(filename)#\(fragment ?? "")"
        context.coordinator.fragment = fragment
        if context.coordinator.loadedKey == key { return }

        let loadedFile = context.coordinator.loadedKey?
            .split(separator: "#", maxSplits: 1)
            .first
            .map(String.init)
        if loadedFile == filename, context.coordinator.didLoadHTML {
            context.coordinator.loadedKey = key
            context.coordinator.scrollToFragment(in: webView)
            return
        }

        guard let url = Bundle.main.url(forResource: filename, withExtension: "html") else { return }
        context.coordinator.loadedKey = key
        context.coordinator.didLoadHTML = true
        // Real file load so #privacy / #terms / #security and sibling Help.html
        // links resolve. loadHTMLString blocked those as local-resource navigations.
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    /// Policy HTML + stylesheet only — never lateral loads into tapper.html.
    private static let allowedFileBasenames: Set<String> = [
        "Help.html",
        "legal-doc.css"
    ]

    /// Passerby shell filenames. Open the hosted card in Safari — do not dump
    /// an empty tapper.html into the Help webview.
    private static let passerbyShellFiles: Set<String> = [
        "tapper.html",
        "index.html",
        "card.html"
    ]

    /// Blocks in-webview navigation to untrusted schemes; opens http(s)/tel/mailto/redmed externally.
    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedKey: String?
        var fragment: String?
        var didLoadHTML = false

        func scrollToFragment(in webView: WKWebView) {
            guard let fragment else { return }
            jumpToPolicyFragment(fragment, in: webView)
        }

        func jumpToPolicyFragment(_ id: String, in webView: WKWebView) {
            let safe = id.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            guard safe == id, !safe.isEmpty else { return }
            // replaceState, not location.hash — assigning hash can reload the file.
            // window.__rmShowPolicy (defined in Help.html) switches the colored
            // tab and hides the other three sections; fall back to a plain
            // scroll if the page's own script hasn't run yet for some reason.
            webView.evaluateJavaScript(
                """
                (function(){
                  var id = '\(safe)';
                  if (typeof window.__rmShowPolicy === 'function') {
                    window.__rmShowPolicy(id, true);
                  } else {
                    var el = document.getElementById(id);
                    if (el) el.scrollIntoView({block:'start'});
                  }
                  try { history.replaceState(null, '', '#' + id); } catch (e) {}
                })();
                """
            )
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.flashScrollIndicators()
            scrollToFragment(in: webView)
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
            if url.isFileURL {
                let name = url.lastPathComponent
                if LocalWebView.passerbyShellFiles.contains(name) {
                    if let hosted = Self.hostedPasserbyURL(from: url) {
                        UIApplication.shared.open(hosted, options: [:], completionHandler: nil)
                    }
                    decisionHandler(.cancel)
                    return
                }
                if navigationAction.navigationType == .linkActivated,
                   let dest = Self.policyDestination(file: name, fragment: url.fragment),
                   isShowingHelp(webView) {
                    decisionHandler(.cancel)
                    fragment = dest
                    jumpToPolicyFragment(dest, in: webView)
                    return
                }
                if LocalWebView.allowedFileBasenames.contains(name) {
                    if let dest = url.fragment, !dest.isEmpty {
                        fragment = dest
                    }
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }
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

        private func isShowingHelp(_ webView: WKWebView) -> Bool {
            if webView.url?.lastPathComponent == "Help.html" { return true }
            if loadedKey?.split(separator: "#", maxSplits: 1).first.map(String.init) == "Help" {
                return true
            }
            return false
        }

        /// AppConfig write base + any `#d=` / search from a bundled tapper.html tap.
        private static func hostedPasserbyURL(from fileURL: URL) -> URL? {
            var raw = AppConfig.medicalCardBaseURL
            if let query = fileURL.query, !query.isEmpty {
                let sep = raw.contains("?") ? "&" : "?"
                raw += sep + query
            }
            if let fragment = fileURL.fragment, !fragment.isEmpty {
                raw += "#" + fragment
            }
            return URL(string: raw)
        }

        private static let helpFragments: Set<String> = Set(HelpDocument.Policy.allCases.map(\.fragment))

        private static func policyDestination(file: String, fragment: String?) -> String? {
            guard file == "Help.html", let fragment, helpFragments.contains(fragment) else {
                return nil
            }
            return fragment
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Deny target=_blank / window.open — no popup webviews from policy HTML.
            if let url = navigationAction.request.url,
               !url.isFileURL {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return nil
        }
    }
}

// MARK: - Help menu
struct HelpMenuView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.isScannerSession) private var isScannerSession
    @EnvironmentObject private var profile: ProfileData
    /// Settings (Haptic feedback / Location) moved to `ConsentGateView` — read
    /// here only to gate the location-suggester refresh below.
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @ObservedObject private var locationSuggester = LocationAccessSuggester.shared
    var onOpenNFC: (() -> Void)? = nil

    @State private var showEraseConfirm = false
    @State private var isErasing = false
    @State private var eraseAuthFailed = false
    @State private var authUnavailableMessage: String?

    /// Same metrics as Edit — even horizontal rhythm across Help / Edit.
    private enum Metrics {
        static let font: CGFloat = 15
        static let rowHPad: CGFloat = RedMedChrome.pagePadX
        static let rowVPad: CGFloat = 13
        static let sectionGap: CGFloat = 22
    }

    /// Owner-only: Erase, Write to NFC. Scanner Help is policies only.
    /// Settings (Haptic feedback / Location) lives on `ConsentGateView` now.
    private var showsOwnerTools: Bool { !isScannerSession }

    private var firstHelpSection: String {
        if showsOwnerTools, onOpenNFC != nil { return "Bracelet" }
        return "Policies"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OwnerModalChrome(
                    title: "Help",
                    leadingTitle: "Done",
                    leadingAction: { dismiss() }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if showsOwnerTools, let onOpenNFC {
                            helpSectionLabel("Bracelet")
                            helpCard {
                                Button {
                                    dismiss()
                                    DispatchQueue.main.async { onOpenNFC() }
                                } label: {
                                    HStack(spacing: 10) {
                                        Text("🪪")
                                            .font(.system(size: 17))
                                            .frame(width: 22, alignment: .center)
                                            .accessibilityHidden(true)
                                        Text("Write The Band")
                                            .font(.system(size: Metrics.font, weight: .medium))
                                            .foregroundColor(.redmedDark)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, Metrics.rowHPad)
                                    .padding(.vertical, Metrics.rowVPad)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Write The Band")
                            }
                        }

                        helpSectionLabel("Policies")
                        helpCard {
                            ForEach(HelpDocument.Policy.allCases) { policy in
                                if policy != .privacy {
                                    Divider().padding(.leading, Metrics.rowHPad)
                                }
                                policyLink(policy)
                            }
                        }

                        if showsOwnerTools {
                            helpSectionLabel("Data")
                            helpCard {
                                Button(role: .destructive) {
                                    showEraseConfirm = true
                                } label: {
                                    Group {
                                        if isErasing {
                                            ProgressView()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            HStack(spacing: 10) {
                                                Text("🗑️")
                                                    .font(.system(size: 17))
                                                    .frame(width: 22, alignment: .center)
                                                    .accessibilityHidden(true)
                                                Text("Erase All User Data")
                                                    .font(.system(size: Metrics.font, weight: .medium))
                                                    .foregroundColor(.redmedAccent)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, Metrics.rowHPad)
                                    .padding(.vertical, Metrics.rowVPad)
                                    .contentShape(Rectangle())
                                }
                                .disabled(isErasing)
                                .accessibilityLabel("Erase All User Data")
                            }
                            Text("Deletes the profile from this iPhone’s Keychain and clears local history. Settings prefs stay. The physical band is not wiped remotely — rewrite or discard it.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, Metrics.rowHPad)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.visible)
            }
            .background { RedMedPageBackground() }
            .tint(.redmedAccent)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard showsOwnerTools, locationEnabled else { return }
                locationSuggester.refresh()
            }
            .confirmationDialog(
                "Erase All User Data On This iPhone?",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("Erase Everything", role: .destructive) {
                    requestErase()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Face ID or passcode is required. Profile and local history are removed from this phone. The bracelet still holds its last write until you overwrite or discard it.")
            }
            .alert("Couldn't verify it's you", isPresented: $eraseAuthFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Face ID, Touch ID, or passcode is required to erase RedMed data.")
            }
            .alert(BiometricAuth.unavailableAlertTitle, isPresented: Binding(
                get: { authUnavailableMessage != nil },
                set: { if !$0 { authUnavailableMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authUnavailableMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func helpSectionLabel(_ text: String) -> some View {
        SectionLabel(text: text)
            .padding(.top, text == firstHelpSection ? 0 : Metrics.sectionGap)
    }

    @ViewBuilder
    private func helpCard<Content: View>(
        flatten: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) { content() }
            .redmedBox(flatten: flatten)
    }

    @ViewBuilder
    private func policyLink(_ policy: HelpDocument.Policy) -> some View {
        NavigationLink {
            LocalWebView(filename: HelpDocument.bundledFile, fragment: policy.fragment)
                .navigationTitle(policy.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(Color.redmedBg, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
        } label: {
            HStack(spacing: 10) {
                Text(policy.emoji)
                    .font(.system(size: 17))
                    .frame(width: 22, alignment: .center)
                    .accessibilityHidden(true)
                Text(policy.title)
                    .font(.system(size: Metrics.font, weight: .medium))
                    .foregroundColor(.redmedDark)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.redmedMuted.opacity(0.55))
            }
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(policy.title)

    private func requestErase() {
        guard showsOwnerTools, !isErasing else { return }
        isErasing = true
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to erase all user data on this iPhone.",
            force: true
        ) { outcome in
            switch outcome {
            case .success:
                profile.eraseAllLocalData()
                RedMedHaptics.success()
                isErasing = false
                dismiss()
            case .notVerified:
                RedMedHaptics.error()
                isErasing = false
                eraseAuthFailed = true
                VaultHistoryStore.shared.record(.unlockFailed, detail: "erase")
            case .unavailable(let reason):
                RedMedHaptics.error()
                isErasing = false
                authUnavailableMessage = reason.message
                VaultHistoryStore.shared.record(.unlockFailed, detail: "erase")
            case .declined, .notInteractive, .timedOut:
                isErasing = false
            }
        }
    }
}
