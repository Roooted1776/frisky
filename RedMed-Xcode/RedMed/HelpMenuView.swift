import SwiftUI
import WebKit

// MARK: - WebView wrapper
struct LocalWebView: UIViewRepresentable {
    let filename: String // e.g. "PrivacyPolicy"

    func makeUIView(context: Context) -> WKWebView { WKWebView() }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

// MARK: - Help menu
struct HelpMenuView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.dismiss) var dismiss
    /// Open the NFC write tab (no Get / Accept page in front of it).
    var onOpenNFC: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            List {
                if AppConfig.nfcHardwareEnabled {
                    if nfcGate.isAccepted {
                        Button("Write your band") {
                            dismiss()
                            DispatchQueue.main.async { onOpenNFC?() }
                        }
                        .foregroundColor(.redmedDark)
                    } else {
                        NavigationLink("Set up your band") {
                            GetView(onAccept: {
                                dismiss()
                                DispatchQueue.main.async { onOpenNFC?() }
                            })
                        }
                    }
                }
                .foregroundColor(.redmedDark)
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
                NavigationLink("How It Works") {
                    LocalWebView(filename: "HowItWorks")
                        .navigationTitle("How It Works")
                        .navigationBarTitleDisplayMode(.inline)
                }
                // Local tap-page source stays in the bundle; only surface it after a band is paired.
                if AppConfig.nfcHardwareEnabled, profile.braceletLinked {
                    NavigationLink("NFC tap card (local)") {
                        LocalWebView(filename: "card")
                            .navigationTitle("NFC tap card")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .navigationTitle("Policies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.redmedAccent)
                }
            }
        }
    }
}
