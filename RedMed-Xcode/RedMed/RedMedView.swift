import SwiftUI

/// Owner / scanner RedMed tab — same bundled `get.html` medical panel helpers see
/// on a band tap. Owner keeps Edit + Help chrome; scanners keep Back. Native
/// 911 / Aid / NFC tabs stay separate (HTML tab bar hidden in app-embed).
struct RedMedView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @Binding var tab: AppTab
    @State private var showEdit = false
    /// When true, Edit opened without Face ID (empty RedMed profile) — Save must authenticate.
    @State private var requireAuthOnSave = false
    @State private var showHelp = false
    @State private var showAuthFailedAlert = false

    private var packedPayload: String? {
        PasserbyHTMLCardView.payload(from: profile)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let packedPayload {
                    PasserbyHTMLShell(
                        encodedPayload: packedPayload,
                        braceletLinked: profile.showsBraceletAsLinked
                    )
                } else {
                    VStack(spacing: 12) {
                        Text("Couldn't pack get.html#d= from RedMed.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .multilineTextAlignment(.center)
                        if !isScannerSession {
                            ChromeTextAction(title: "Edit") { requestEdit() }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(alignment: .center, spacing: 12) {
                if isScannerSession {
                    ScannerBackButton()
                    Spacer(minLength: 0)
                } else {
                    ChromeTextAction(title: "Help") { showHelp = true }
                    Spacer(minLength: 0)
                    ChromeTextAction(title: "Edit") { requestEdit() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
        // Owner profile only — never redact the passerby / EMS scanner card.
        .privacySensitive(!isScannerSession)
        .background { RedMedPageBackground() }
        .fullScreenCover(isPresented: Binding(
            get: { showEdit && !isScannerSession },
            set: { showEdit = $0 && !isScannerSession }
        )) {
            EditProfileView(requireAuthOnSave: requireAuthOnSave)
                .environmentObject(profile)
        }
        .sheet(isPresented: Binding(
            get: { showHelp && !isScannerSession },
            set: { showHelp = $0 && !isScannerSession }
        )) {
            HelpMenuView(onOpenNFC: { tab = .nfc })
        }
        .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to edit your RedMed profile.")
        }
    }

    // MARK: - Edit gate

    private func requestEdit() {
        // Scanners never edit — UI gate alone is not enough.
        guard !isScannerSession else { return }
        guard profile.hasSensitiveProfileData else {
            // First fill: open freely, Face ID on Save (see EditProfileView.requireAuthOnSave).
            requireAuthOnSave = true
            showEdit = true
            return
        }
        BiometricAuth.authenticate(
            reason: "Unlock with Face ID, Touch ID, or passcode to edit your RedMed profile."
        ) { outcome in
            if outcome == .success {
                requireAuthOnSave = false
                showEdit = true
            } else if outcome == .notVerified {
                showAuthFailedAlert = true
            }
        }
    }
}
