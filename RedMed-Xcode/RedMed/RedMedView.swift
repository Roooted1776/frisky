import SwiftUI

/// Owner / scanner RedMed tab — same bundled `tapper.html` medical panel helpers see
/// on a band tap. Owner keeps Help · Edit top chrome + Preview at the bottom; scanners
/// keep Back. Native 911 / Aid / NFC tabs stay separate (HTML tab bar hidden in app-embed).
struct RedMedView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @Binding var tab: AppTab
    @State private var showEdit = false
    /// When true, Edit opened without Face ID (empty RedMed profile) — Save must authenticate.
    @State private var requireAuthOnSave = false
    @State private var showHelp = false
    @State private var showPreview = false
    @State private var showAuthFailedAlert = false
    /// Cached `#d=` — never AES-pack inside `body` (random nonce remounted WKWebView).
    @State private var packedPayload: String?
    @State private var packFingerprint = ""
    @State private var packGeneration = 0
    /// True after the first pack attempt finishes — avoids a mid-screen Edit under chrome while packing.
    @State private var packFinished = false

    /// Durable profile fields only — ignores `holdsEditingSession` so Edit open/close
    /// does not rebuild the shell.
    private var profilePackFingerprint: String {
        let contacts = profile.contacts
            .map { "\($0.name)|\($0.relationship)|\($0.phone)" }
            .joined(separator: ";")
        return [
            profile.name,
            profile.birthDate,
            profile.bloodType,
            profile.allergies.joined(separator: ","),
            profile.medications.joined(separator: ","),
            profile.conditions.joined(separator: ","),
            contacts,
            profile.isOrganDonor ? "1" : "0",
            profile.lastUpdated,
            profile.showsBraceletAsLinked ? "1" : "0"
        ].joined(separator: "\u{1e}")
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let packedPayload {
                    PasserbyHTMLShell(
                        encodedPayload: packedPayload,
                        braceletLinked: profile.showsBraceletAsLinked
                    )
                    // Opacity tab swaps must not animate WKWebView (jank + flash).
                    .transaction { $0.animation = nil }
                } else if packFinished {
                    VStack(spacing: 12) {
                        Text("Couldn't pack tapper.html#d= from RedMed.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Cream only while packing — no mid-screen Edit under the chrome row.
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Top chrome — Help · Edit tight (same accent text). Preview sits at the bottom.
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 4) {
                    if isScannerSession {
                        ScannerBackButton()
                        Spacer(minLength: 0)
                    } else {
                        // Help · Edit tight, same accent text — Preview is bottom.
                        ChromeTextAction(title: "Help") { showHelp = true }
                        ChromeTextAction(title: "Edit") { requestEdit() }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Spacer(minLength: 0)

                if !isScannerSession {
                    ChromeTextAction(title: "Preview") { openPreview() }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                }
            }
        }
        // Owner profile only — never redact the passerby / EMS scanner card.
        .privacySensitive(!isScannerSession)
        .background { RedMedPageBackground() }
        .onAppear { syncPackedPayload() }
        .onChange(of: profilePackFingerprint) { _, _ in syncPackedPayload() }
        .fullScreenCover(isPresented: Binding(
            get: { showEdit && !isScannerSession },
            set: { showEdit = $0 && !isScannerSession }
        )) {
            EditProfileView(requireAuthOnSave: requireAuthOnSave)
                .environmentObject(profile)
        }
        .fullScreenCover(isPresented: Binding(
            get: { showPreview && !isScannerSession && packedPayload != nil },
            set: { showPreview = $0 && !isScannerSession }
        )) {
            PasserbyHTMLCardView(
                payloadOrURL: packedPayload ?? "",
                braceletLinked: profile.showsBraceletAsLinked
            )
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

    private func openPreview() {
        guard !isScannerSession else { return }
        // Prefer cached pack; if still packing, mint once on the tap path.
        if packedPayload == nil {
            packedPayload = PasserbyHTMLCardView.previewPayload(from: profile)
        }
        guard packedPayload != nil else { return }
        RedMedHaptics.light()
        showPreview = true
    }

    private func syncPackedPayload() {
        let fp = profilePackFingerprint
        guard fp != packFingerprint || packedPayload == nil else { return }
        packFingerprint = fp
        packGeneration &+= 1
        let generation = packGeneration
        packFinished = false
        // Yield first paint (cream shell), then pack on main — ProfileData is not concurrent.
        Task { @MainActor in
            await Task.yield()
            guard generation == packGeneration else { return }
            packedPayload = PasserbyHTMLCardView.previewPayload(from: profile)
            packFinished = true
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
                VaultHistoryStore.shared.record(.unlockFailed, detail: "edit")
            }
        }
    }
}
