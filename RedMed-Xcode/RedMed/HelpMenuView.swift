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
    @ObservedObject private var nfcGate = NFCAccessGate.shared
    /// After Accept on Get (or immediately if already accepted), open the NFC tab.
    var onOpenNFC: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            List {
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
                if profile.braceletLinked {
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
