import SwiftUI
import WebKit
import UIKit

// MARK: - WebView wrapper (policies + passerby card only)
struct LocalWebView: UIViewRepresentable {
    let filename: String // e.g. "PrivacyPolicy"

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
        guard context.coordinator.loadedFilename != filename else { return }
        guard let url = Bundle.main.url(forResource: filename, withExtension: "html"),
              var html = try? String(contentsOf: url, encoding: .utf8) else { return }
        context.coordinator.loadedFilename = filename
        // Cream before first paint — file loads can flash system white before CSS.
        let cream = "<style>html,body{background:#fff7f7!important;margin:0}</style>\n"
        if let range = html.range(of: "<head>") {
            html.replaceSubrange(range, with: "<head>\n" + cream)
        } else {
            html = cream + html
        }
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }

    /// Policy HTML + stylesheet only — never lateral loads into tapper.html / other bundle files.
    private static let allowedFileBasenames: Set<String> = [
        "PrivacyPolicy.html",
        "TOS.html",
        "security.html",
        // Redirect-only → redmed://main (iPhone) or tapper.html (any device).
        "HowItWorks.html",
        "legal-doc.css",
        // Passerby card — policy “Emergency card (any phone)” CTA.
        "tapper.html",
        "BrandLogo.png",
        "BrandWordmark.png",
        "sw.js"
    ]

    /// Blocks in-webview navigation to untrusted schemes; opens http(s)/tel/mailto/redmed externally.
    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedFilename: String?

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
            if url.isFileURL {
                let name = url.lastPathComponent
                if LocalWebView.allowedFileBasenames.contains(name) {
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
    @EnvironmentObject private var profile: ProfileData
    @AppStorage(RedMedHaptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @ObservedObject private var locationSuggester = LocationAccessSuggester.shared
    var onOpenNFC: (() -> Void)? = nil

    @State private var showEraseConfirm = false
    @State private var isErasing = false
    @State private var eraseAuthFailed = false
    @State private var eraseDone = false

    /// Same metrics as Edit — even horizontal rhythm across Help / Edit.
    private enum Metrics {
        static let font: CGFloat = 15
        static let rowHPad: CGFloat = RedMedChrome.pagePadX
        static let rowVPad: CGFloat = 13
        static let sectionGap: CGFloat = 22
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
                        if onOpenNFC != nil {
                            helpSectionLabel("Bracelet")
                            helpCard {
                                Button {
                                    dismiss()
                                    DispatchQueue.main.async { onOpenNFC?() }
                                } label: {
                                    Text("Write to NFC tag")
                                        .font(.system(size: Metrics.font, weight: .medium))
                                        .foregroundColor(.redmedDark)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, Metrics.rowHPad)
                                        .padding(.vertical, Metrics.rowVPad)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        helpSectionLabel("Settings")
                        helpCard {
                            Toggle("Haptic feedback", isOn: $hapticsEnabled)
                                .font(.system(size: Metrics.font))
                                .tint(.redmedAccent)
                                .padding(.horizontal, Metrics.rowHPad)
                                .padding(.vertical, Metrics.rowVPad)
                            Divider().padding(.leading, Metrics.rowHPad)
                            Toggle("Location", isOn: $locationEnabled)
                                .font(.system(size: Metrics.font))
                                .tint(.redmedAccent)
                                .padding(.horizontal, Metrics.rowHPad)
                                .padding(.vertical, Metrics.rowVPad)
                                .onChange(of: locationEnabled) { _, on in
                                    // Pref only — never call requestWhenInUseAuthorization here.
                                    // Find Help prompts the system sheet once when GPS is actually needed.
                                    if on { locationSuggester.refresh() }
                                }
                            if locationEnabled && locationSuggester.mustOpenSettings {
                                Divider().padding(.leading, Metrics.rowHPad)
                                Button("Open iOS Location Settings") {
                                    locationSuggester.openSettings()
                                }
                                .font(.system(size: Metrics.font, weight: .medium))
                                .foregroundColor(.redmedAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Metrics.rowHPad)
                                .padding(.vertical, Metrics.rowVPad)
                            }
                        }
                        Text("Location defaults on. No RedMed popup — iOS may ask Allow once the first time Find Help needs GPS (Apple requires that tap). Siren / max volume / brightness arm on crash or SOS only.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                        helpSectionLabel("Policies")
                        helpCard {
                            policyLink("Privacy Policy", file: "PrivacyPolicy")
                            Divider().padding(.leading, Metrics.rowHPad)
                            policyLink("Terms of Service", file: "TOS")
                            Divider().padding(.leading, Metrics.rowHPad)
                            policyLink("Security", file: "security")
                        }

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
                                        Text("Erase all RedMed data")
                                            .font(.system(size: Metrics.font, weight: .medium))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, Metrics.rowHPad)
                                .padding(.vertical, Metrics.rowVPad)
                                .contentShape(Rectangle())
                            }
                            .disabled(isErasing || (!profile.hasSensitiveProfileData && !ProfileData.prefersLockOnLaunch))
                        }
                        Text("Deletes the profile from this iPhone’s Keychain and clears local history. Settings prefs stay. The physical band is not wiped remotely — rewrite or discard it.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, Metrics.rowHPad)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.visible)
            }
            .background { RedMedPageBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if locationEnabled {
                    locationSuggester.refresh()
                }
            }
            .confirmationDialog(
                "Erase all RedMed data on this iPhone?",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("Erase everything", role: .destructive) {
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
            .alert("RedMed data erased", isPresented: $eraseDone) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("This iPhone no longer holds your RedMed profile. Rewrite or discard the band if it still has a card.")
            }
        }
    }

    @ViewBuilder
    private func helpSectionLabel(_ text: String) -> some View {
        SectionLabel(text: text)
            .padding(.top, text == "Bracelet" || (text == "Settings" && onOpenNFC == nil) ? 0 : Metrics.sectionGap)
    }

    @ViewBuilder
    private func helpCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .redmedBox()
    }

    @ViewBuilder
    private func policyLink(_ title: String, file: String) -> some View {
        NavigationLink {
            LocalWebView(filename: file)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(Color.redmedBg, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
        } label: {
            HStack {
                Text(title)
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
    }

    private func requestErase() {
        guard !isErasing else { return }
        isErasing = true
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to erase all RedMed data on this iPhone."
        ) { outcome in
            switch outcome {
            case .success:
                profile.eraseAllLocalData()
                RedMedHaptics.success()
                isErasing = false
                eraseDone = true
            case .notVerified:
                RedMedHaptics.error()
                isErasing = false
                eraseAuthFailed = true
                VaultHistoryStore.shared.record(.unlockFailed, detail: "erase")
            case .declined, .notInteractive:
                isErasing = false
            }
        }
    }
}
