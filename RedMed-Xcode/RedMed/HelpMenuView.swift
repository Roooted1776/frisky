import SwiftUI
import WebKit

// MARK: - WebView wrapper (policies + passerby card only)
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
    @AppStorage(HapticEngine.enabledKey) private var hapticsEnabled = true
    var onOpenNFC: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            List {
                if onOpenNFC != nil {
                    Button("Write your band") {
                        dismiss()
                        DispatchQueue.main.async { onOpenNFC?() }
                    }
                    .foregroundColor(.redmedDark)
                }
                Section("Settings") {
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                        .tint(.redmedAccent)
                    Text("CPR beat taps use the Taptic Engine on a physical iPhone. Simulator still runs — haptics are skipped. Turn off here, or System Haptics in iOS Settings → Sounds & Haptics. Face ID is device-only; Simulator Edit/NFC uses an Authenticate prompt.")
                        .font(.system(size: 12))
                        .foregroundColor(.redmedMuted)
                        .listRowSeparator(.hidden)
                }
                NavigationLink("How It Works") {
                    // Owner info lives in Main.swift — not HowItWorks.html
                    MainInfoView(onOpenNFC: onOpenNFC)
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
                // Owner-only vault dashboard — Face ID gated inside the view.
                NavigationLink("Local History") {
                    VaultHistoryView()
                }
                if profile.braceletLinked {
                    NavigationLink("NFC tap card (local)") {
                        LocalWebView(filename: "get")
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
