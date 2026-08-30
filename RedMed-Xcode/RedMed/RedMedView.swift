import SwiftUI

/// Owner / scanner RedMed tab — same bundled `tapper.html` medical panel helpers see
/// on a band tap. Owner top chrome is the tapper YOU-card header (logo + name +
/// Linked) with Edit trailing (no bottom Help dock). Scanners keep Back top chrome.
/// Help lives on 911 / Aid / NFC — not on Edit.
/// First-responder Preview lives on the NFC tab under Scan — not here.
/// Native 911 / Aid / NFC tabs stay separate (HTML tab bar hidden in app-embed).
///
/// Fresh install (owner, empty profile): native setup funnel instead of an empty
/// YOU card — Fill ID → Save → Write band. Passerby tapper is unchanged.
struct RedMedView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    /// ContentView keep-alive never calls `onDisappear`. Pass whether RedMed
    /// is the front tab so a parked WKWebView can recover if WebKit died.
    var isVisible: Bool = true
    @State private var showEdit = false
    /// When true, Edit opened without Face ID (empty RedMed profile) — Save must authenticate.
    @State private var requireAuthOnSave = false
    @State private var showAuthFailedAlert = false
    @State private var authUnavailableMessage: String?
    /// Cached `#d=` — never AES-pack inside `body` (random nonce remounted WKWebView).
    @State private var packedPayload: String?
    /// Plaintext JSON paired with `packedPayload` — avoids remount when profile publishes mid-apply.
    @State private var cachedEmbedJSON: String?
    @State private var packFingerprint = ""
    @State private var packGeneration = 0
    /// True after the first pack attempt finishes — avoids a mid-screen Edit under chrome while packing.
    @State private var packFinished = false
    @State private var healthImportBusy = false
    @State private var healthImportMessage: String?
    /// HealthKit characteristics to seed Edit. Not written to ProfileData until Save.
    @State private var healthSeed: HealthKitProfileImport.Draft?

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

    /// Prefer live cache; else placeholder so a filled profile never paints cream.
    /// Nil while restoring or on the empty funnel so those states can show cream / setup.
    private var shellPayload: String? {
        if let packedPayload { return packedPayload }
        if showsOwnerSetupFunnel || profile.isRestoringFromKeychain { return nil }
        return ProfileNFCCodec.placeholderPreviewPayload
    }

    /// Prefer live cache; else live profile embed JSON.
    private var shellEmbedJSON: String? {
        cachedEmbedJSON
            ?? ProfileNFCCodec.embedProfileJSON(from: profile)
    }

    /// Owner empty profile — native steps instead of a blank YOU card.
    /// Hidden while a stored ID is expected or restore is in flight (cream, not funnel).
    private var showsOwnerSetupFunnel: Bool {
        !isScannerSession
            && !profile.hasSensitiveProfileData
            && !profile.isRestoringFromKeychain
            && !ProfileData.prefersLockOnLaunch
            && !ProfileData.hasStoredProfile()
    }

    var body: some View {
        // Chrome is a sibling of the WKWebView — never an overlay. Overlaying
        // Edit on UIKit WebView lets the web view steal taps (Edit looks dead).
        VStack(spacing: 0) {
            if isScannerSession {
                HStack(alignment: .center, spacing: 12) {
                    ScannerBackButton()
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .redmedTopChromeFill()
            } else {
                RedMedUserHeader(
                    name: profile.name,
                    linked: profile.showsBraceletAsLinked,
                    onEdit: { requestEdit() },
                    onStatus: {
                        NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                    }
                )
            }

            Group {
                if showsOwnerSetupFunnel {
                    OwnerSetupFunnel(
                        healthBusy: healthImportBusy,
                        healthMessage: healthImportMessage,
                        onFill: { requestEdit() },
                        onHealthImport: { Task { await importFromHealthThenEdit() } }
                    )
                } else if profile.isRestoringFromKeychain {
                    Color.redmedBg
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let shellPayload {
                    VStack(spacing: 0) {
                        if !isScannerSession {
                            ownerNextStepBanner
                        }
                        PasserbyHTMLShell(
                            encodedPayload: shellPayload,
                            braceletLinked: profile.showsBraceletAsLinked,
                            embedProfileJSON: shellEmbedJSON,
                            pageVisible: isVisible
                        )
                        // Opacity tab swaps must not animate WKWebView (jank + flash).
                        .transaction { $0.animation = nil }
                    }
                } else if packFinished {
                    VStack(spacing: 14) {
                        Text("Couldn't load your medical card.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .multilineTextAlignment(.center)
                        PrimaryButton(title: "Try again") {
                            packFinished = false
                            packedPayload = nil
                            syncPackedPayload()
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.redmedBg
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Big bottom "Help" dock removed from the RedMed user page.
            // Help remains available via other native chrome on the
            // 911 / Aid / NFC tabs (not the Edit modal bar).
        }
        // Owner profile only — never redact the passerby / EMS scanner card.
        .privacySensitive(!isScannerSession)
        .background { RedMedPageBackground() }
        .onAppear { adoptUnlockPreviewOrSync() }
        .onChange(of: profile.isRestoringFromKeychain) { _, restoring in
            if !restoring { adoptUnlockPreviewOrSync() }
        }
        .onChange(of: profilePackFingerprint) { _, _ in syncPackedPayload() }
        .fullScreenCover(isPresented: Binding(
            get: { showEdit && !isScannerSession },
            set: { showEdit = $0 && !isScannerSession }
        )) {
            EditProfileView(requireAuthOnSave: requireAuthOnSave, healthSeed: healthSeed)
                .environmentObject(profile)
                .presentationBackground(Color.redmedBg)
        }
        .alert(BiometricAuth.deniedAlertTitle, isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(BiometricAuth.deniedAlertMessage(action: "edit"))
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

    /// Sibling above the YOU card — never an overlay on the tap card.
    @ViewBuilder
    private var ownerNextStepBanner: some View {
        if !profile.isEmergencyProfileConfigured {
            OwnerNextStepBanner(
                icon: "square.and.pencil",
                title: "Finish your medical ID",
                detail: "Add birth date and blood type so helpers see a complete ID.",
                actionTitle: "Edit",
                action: { requestEdit() }
            )
        } else if !profile.showsBraceletAsLinked {
            OwnerNextStepBanner(
                icon: "wave.3.right",
                title: AppConfig.nfcHardwareEnabled ? "Write your band" : "Preview the helper card",
                detail: AppConfig.nfcHardwareEnabled
                    ? "Write the band on the NFC tab so a passerby tap opens this card."
                    : "Band write is preview-only in this build. Open NFC to see what helpers would see.",
                actionTitle: "NFC",
                action: {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            )
        }
    }

    /// First paint: live packed payload / embed JSON from the profile in RAM.
    /// Durable AES refreshes in the background via JS push — no cream stall.
    private func adoptUnlockPreviewOrSync() {
        if profile.isRestoringFromKeychain { return }
        if packedPayload == nil {
            cachedEmbedJSON = ProfileNFCCodec.embedProfileJSON(from: profile)
            packedPayload = ProfileNFCCodec.placeholderPreviewPayload
            packFingerprint = profilePackFingerprint
            packFinished = true
            refreshDurablePayload()
            return
        }
        syncPackedPayload()
    }

    /// AES `#d=` after first paint — `updateUIView` JS-pushes without remounting.
    private func refreshDurablePayload() {
        packGeneration &+= 1
        let generation = packGeneration
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        Task.detached(priority: .utility) {
            let payload = ProfileNFCCodec.previewPayload(from: chip)
            await MainActor.run {
                guard generation == packGeneration, let payload else { return }
                packedPayload = payload
            }
        }
    }

    private func syncPackedPayload() {
        let fp = profilePackFingerprint
        guard fp != packFingerprint || packedPayload == nil else { return }
        packFingerprint = fp
        packGeneration &+= 1
        let generation = packGeneration
        // Keep any live shell while packing off-main — clearing blanked RedMed until AES finished.
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        // Paint immediately with embed JSON if the shell is empty.
        if packedPayload == nil {
            packedPayload = ProfileNFCCodec.placeholderPreviewPayload
            cachedEmbedJSON = ProfileNFCCodec.embedProfileJSON(from: chip)
            packFinished = true
        }
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
            reason: "Unlock with Face ID, Touch ID, or passcode to edit your RedMed profile.",
            force: true
        ) { outcome in
            if outcome == .success {
                requireAuthOnSave = false
                showEdit = true
            } else if outcome == .notVerified {
                showAuthFailedAlert = true
                VaultHistoryStore.shared.record(.unlockFailed, detail: "edit")
            } else if case .unavailable(let reason) = outcome {
                authUnavailableMessage = reason.message
            }
        }
    }

    /// Optional Health fill on the empty funnel, then Edit so Save still Face ID gates persist.
    @MainActor
    private func importFromHealthThenEdit() async {
        guard !isScannerSession, !healthImportBusy else { return }
        healthImportBusy = true
        healthImportMessage = nil
        defer { healthImportBusy = false }
        do {
            let draft = try await HealthKitProfileImport.readCharacteristics()
            healthSeed = draft
            healthImportMessage = draft.filledCount == 2
                ? "Birth date and blood type ready. Add your name, then Save."
                : "Copied from Apple Health. Add your name, then Save."
            requireAuthOnSave = true
            showEdit = true
        } catch {
            healthImportMessage = error.localizedDescription
        }
    }
}

// MARK: - Tapper header (owner RedMed)

/// Same YOU-card header as passerby `tapper.html` `.rm-header` — logo, name,
/// Linked / Not linked — with Edit as trailing chrome. Sibling of the WKWebView,
/// never an overlay. Scanner / Preview keep HTML header + Back.
private struct RedMedUserHeader: View {
    let name: String
    let linked: Bool
    var onEdit: () -> Void
    var onStatus: () -> Void

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "RedMed" : trimmed
    }

    private var statusTitle: String {
        linked ? "Linked bracelet" : "Not linked"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("BrandLogo")
                .resizable()
                .scaledToFill()
                .frame(width: RedMedChrome.logoSize, height: RedMedChrome.logoSize)
                .clipShape(Circle())
                .shadow(color: Color.redmedAccent.opacity(0.18), radius: 10, y: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.5)
                    .foregroundColor(.redmedDark)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onStatus) {
                    HStack(spacing: 2) {
                        Text(statusTitle)
                            .font(.system(size: 12, weight: .bold))
                            .kerning(0.5)
                            .textCase(.uppercase)
                        Text("›")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.redmedAccent)
                }
                .buttonStyle(RedMedPressStyle(scale: 0.98, haptic: nil))
                .accessibilityLabel(statusTitle)
                .accessibilityHint("Opens NFC")
            }

            Spacer(minLength: 8)

            ChromeTextAction(title: "Edit", action: onEdit)
        }
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .redmedTopChromeWash()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - First-fill funnel (owner empty profile)

/// Native setup on the owner RedMed tab. Replaces the empty YOU card — not an overlay
/// on a live tap card. Scanners never see this.
private struct OwnerSetupFunnel: View {
    var healthBusy: Bool
    var healthMessage: String?
    var onFill: () -> Void
    var onHealthImport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ghostYouCard
                stepsCard
                PrimaryButton(title: "Fill medical ID", action: onFill)
                if HealthKitProfileImport.isAvailable {
                    healthButton
                    Text("Birth date and blood type only. RedMed never writes back to Health.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                }
                if let healthMessage, !healthMessage.isEmpty {
                    Text(healthMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Same YOU-card chrome as tapper — empty slots plus the fill CTA below.
    private var ghostYouCard: some View {
        VStack(spacing: 0) {
            ghostRow(label: "Name", value: "—")
            Divider().overlay(Color.redmedDivider)
            ghostRow(label: "Birth date", value: "—")
            Divider().overlay(Color.redmedDivider)
            ghostRow(label: "Blood type", value: "—")
            Divider().overlay(Color.redmedDivider)
            ghostRow(label: "Organ donor", value: "—")
        }
        .redmedBox()
        .accessibilityHidden(true)
    }

    private func ghostRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.redmedDark.opacity(0.4))
        }
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.vertical, 11)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Get started")
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 2)
            stepRow(number: "1", title: "Fill your medical ID", detail: "Name, birth date, blood type. Allergies and contacts help EMS.")
            Divider().overlay(Color.redmedDivider).padding(.leading, 54)
            stepRow(number: "2", title: "Save", detail: "Face ID writes it to this iPhone's Keychain. Nothing leaves the phone.")
            Divider().overlay(Color.redmedDivider).padding(.leading, 54)
            stepRow(number: "3", title: AppConfig.nfcHardwareEnabled ? "Write the band" : "Preview the helper card", detail: AppConfig.nfcHardwareEnabled ? "NFC tab packs the card onto the chip. Helpers tap. No app, no login." : "NFC tab packs the card for Preview. Live band write ships when NFC Tag Reading is on the App ID.")
        }
        .redmedBox()
    }

    private var healthButton: some View {
        OutlineButton(
            title: healthBusy ? "Reading Apple Health…" : "Fill from Apple Health",
            systemImage: healthBusy ? nil : "heart.text.square",
            busy: healthBusy
        ) {
            onHealthImport()
        }
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.redmedAccent.opacity(0.12))
                Text(number)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.redmedAccent)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.redmedDark)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

/// Compact next-step chip above the YOU card. Sibling of the WKWebView — not an overlay.
private struct OwnerNextStepBanner: View {
    let icon: String
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 28, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.redmedDark)
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                HStack(spacing: 2) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .bold))
                    Text("›")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.redmedAccent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(RedMedPressStyle(scale: 0.98))
        .redmedBox()
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.bottom, 8)
        .accessibilityHint("Opens \(actionTitle)")
    }
}
