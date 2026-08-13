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
        guard let url = Bundle.main.url(forResource: filename, withExtension: "html") else { return }
        context.coordinator.loadedFilename = filename
        // Read access limited to the HTML file's directory (bundle resources).
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
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

    var body: some View {
        NavigationView {
            List {
                if onOpenNFC != nil {
                    Button("Write to NFC tag") {
                        dismiss()
                        DispatchQueue.main.async { onOpenNFC?() }
                    }
                    .foregroundColor(.redmedDark)
                }
                Section {
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                        .tint(.redmedAccent)
                    Toggle("Location", isOn: $locationEnabled)
                        .tint(.redmedAccent)
                        .onChange(of: locationEnabled) { _, on in
                            // Pref only — never call requestWhenInUseAuthorization here.
                            // Find Help prompts the system sheet once when GPS is actually needed.
                            if on { locationSuggester.refresh() }
                        }
                    if locationEnabled && locationSuggester.mustOpenSettings {
                        Button("Open iOS Location Settings") {
                            locationSuggester.openSettings()
                        }
                        .foregroundColor(.redmedAccent)
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    Text("Location defaults on. No RedMed popup — iOS may ask Allow once the first time Find Help needs GPS (Apple requires that tap). Siren / max volume / brightness arm on crash or SOS only.")
                }
                NavigationLink("Privacy Policy") {
                    LocalWebView(filename: "PrivacyPolicy")
                        .navigationTitle("Privacy Policy")
                        .navigationBarTitleDisplayMode(.inline)
                }
                NavigationLink("Terms of Service") {
                    LocalWebView(filename: "TOS")
                        .navigationTitle("Terms of Service")
                        .navigationBarTitleDisplayMode(.inline)
                }
                NavigationLink("Security") {
                    LocalWebView(filename: "security")
                        .navigationTitle("Security")
                        .navigationBarTitleDisplayMode(.inline)
                }
                Section {
                    Button(role: .destructive) {
                        showEraseConfirm = true
                    } label: {
                        if isErasing {
                            ProgressView()
                        } else {
                            Text("Erase all RedMed data")
                        }
                    }
                    .disabled(isErasing || (!profile.hasSensitiveProfileData && !ProfileData.prefersLockOnLaunch))
                } footer: {
                    Text("Deletes the profile from this iPhone’s Keychain and clears local history. Settings prefs stay. The physical band is not wiped remotely — rewrite or discard it.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.visible)
            .background { RedMedPageBackground() }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.redmedBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.redmedAccent)
                }
            }
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
        .navigationViewStyle(.stack)
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
            case .declined:
                isErasing = false
            }
        }
    }
}
