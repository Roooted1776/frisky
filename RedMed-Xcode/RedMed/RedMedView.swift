import SwiftUI

/// Owner / scanner RedMed tab — same bundled `tapper.html` medical panel helpers see
/// on a band tap. Owner keeps Help · Edit top chrome; scanners keep Back.
/// First-responder Preview lives on the NFC tab under Scan — not here.
/// Native 911 / Aid / NFC tabs stay separate (HTML tab bar hidden in app-embed).
struct RedMedView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @Binding var tab: AppTab
    @State private var showEdit = false
    /// When true, Edit opened without Face ID (empty RedMed profile) — Save must authenticate.
    @State private var requireAuthOnSave = false
    @State private var showHelp = false
    @State private var showAuthFailedAlert = false
    /// Cached `#d=` — never AES-pack inside `body` (random nonce remounted WKWebView).
    @State private var packedPayload: String?
    /// Plaintext JSON paired with `packedPayload` — avoids remount when profile publishes mid-apply.
    @State private var cachedEmbedJSON: String?
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

    /// Prefer live cache; else Face ID–overlapped pack so unlock's first frame is not cream-only.
    private var shellPayload: String? {
        packedPayload ?? profile.unlockPreviewPayload
    }

    /// Prefer live cache; else Face ID–overlapped plaintext JSON.
    private var shellEmbedJSON: String? {
        cachedEmbedJSON ?? profile.unlockEmbedProfileJSON
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let shellPayload {
                    PasserbyHTMLShell(
                        encodedPayload: shellPayload,
                        braceletLinked: profile.showsBraceletAsLinked,
                        embedProfileJSON: shellEmbedJSON
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
                    Color.redmedBg
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Opaque cream chrome — Help · Edit must not sit transparent over YOU-card data.
            // Same ChromeTextAction + even gap; Preview lives under NFC Scan.
            HStack(alignment: .center, spacing: 12) {
                if isScannerSession {
                    ScannerBackButton()
                    Spacer(minLength: 0)
                } else {
                    ChromeTextAction(title: "Help") { showHelp = true }
                    ChromeTextAction(title: "Edit") { requestEdit() }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(Color.redmedBg)
        }
        // Owner profile only — never redact the passerby / EMS scanner card.
        .privacySensitive(!isScannerSession)
        .background { RedMedPageBackground() }
        .onAppear { adoptUnlockPreviewOrSync() }
        .onChange(of: profilePackFingerprint) { _, _ in syncPackedPayload() }
        .fullScreenCover(isPresented: Binding(
            get: { showEdit && !isScannerSession },
            set: { showEdit = $0 && !isScannerSession }
        )) {
            EditProfileView(requireAuthOnSave: requireAuthOnSave)
                .environmentObject(profile)
        }
        .fullScreenCover(isPresented: Binding(
            get: { showHelp && !isScannerSession },
            set: { showHelp = $0 && !isScannerSession }
        )) {
            HelpMenuView(onOpenNFC: { tab = .nfc })
                .environmentObject(profile)
        }
        .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to edit your RedMed profile.")
        }
    }

    /// First unlock paint: adopt Face ID–overlapped `#d=` so WKWebView loads without an AES stall.
    private func adoptUnlockPreviewOrSync() {
        if packedPayload == nil, let pending = profile.unlockPreviewPayload {
            // Assign @State before clearing the profile hold so shellPayload never gaps.
            packedPayload = pending
            cachedEmbedJSON = profile.takeUnlockEmbedProfileJSON()
                ?? ProfileNFCCodec.embedProfileJSON(from: profile)
            packFingerprint = profilePackFingerprint
            packFinished = true
            _ = profile.takeUnlockPreviewPayload()
            return
        }
        syncPackedPayload()
    }

    private func syncPackedPayload() {
        let fp = profilePackFingerprint
        guard fp != packFingerprint || packedPayload == nil else { return }
        packFingerprint = fp
        packGeneration &+= 1
        let generation = packGeneration
        // Keep any live shell while packing off-main — clearing blanked RedMed until AES finished.
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        Task.detached(priority: .userInitiated) {
            let artifacts = (
                ProfileNFCCodec.previewPayload(from: chip),
                ProfileNFCCodec.embedProfileJSON(from: chip)
            )
            await MainActor.run {
                guard generation == packGeneration else { return }
                packedPayload = artifacts.0
                cachedEmbedJSON = artifacts.1
                packFinished = true
            }
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
