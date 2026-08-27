// Owner-only NFC bracelet setup. Ped/EMS scanner shells never mount this tab —
// see ContentView.showsNFC / scannerSafeTab.
// One page: Write (blank unlocked NXP NTAG216, ISO 14443A Type 2) + Preview (under
// Write) → full-page tap card (what first responders see).
// When `AppConfig.nfcHardwareEnabled` is true, Write starts a real CoreNFC
// session. Pack-only simulate stays for offline/dev when the flag is off —
// it never flips Linked / Not linked (that needs a real bracelet write).
// Pipeline (hardware): silicone band tap → CoreNFC → strip NDEF → CryptoKit → local card
// via `NFCBandManager`.
import SwiftUI

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @StateObject private var band = NFCBandManager()
    /// Full passerby shell from live RedMed — what first responders see on a band tap.
    /// `item:` presentation so the cover always binds a complete payload (no empty race).
    @State private var previewSession: PreviewSession?

    /// One-shot Preview open — payload + embed JSON must both be set before present.
    private struct PreviewSession: Identifiable {
        let id = UUID()
        let payload: String
        let embedJSON: String?
        let linked: Bool
    }

    var body: some View {
        if isScannerSession {
            Color.redmedBg.ignoresSafeArea()
        } else {
            ownerBody
        }
    }

    private var ownerBody: some View {
        // Fixed cream chrome (no NavigationView / system toolbar) — page
        // BrandWordmark (911 / Aid are content-first; no hanging pane marks).
        // Owner-only tab; scanners never mount this.
        VStack(spacing: 0) {
            PageHelpChrome()
            BrandWordmarkHeader(top: 0)

            ScrollView {
                VStack(spacing: 16) {
                    factsCard
                    setupCard
                        .padding(.top, 4)
                    // Under Write — same tap card first responders get.
                    firstResponderPreviewLink
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.visible)
        }
        .background { RedMedPageBackground() }
        .fullScreenCover(item: $previewSession) { session in
            PasserbyHTMLCardView(
                payloadOrURL: session.payload,
                braceletLinked: session.linked,
                embedProfileJSON: session.embedJSON
            )
            .presentationBackground(Color.redmedBg)
        }
        .alert("Authentication Failed", isPresented: $band.authFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to write your emergency card to the bracelet.")
        }
        .alert("Bracelet", isPresented: Binding(
            get: { band.alertMessage != nil },
            set: { if !$0 { band.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { band.alertMessage = nil }
        } message: {
            Text(band.alertMessage ?? "")
        }
        // Linked reacts to a finished real CoreNFC write only — never pack/simulate.
        // Wait until isWriting clears so success + verified are both settled.
        .onChange(of: band.isWriting) { _, writing in
            guard !writing, band.writeSucceeded, AppConfig.nfcHardwareEnabled else { return }
            let detail = band.writeVerified ? "NFC write verified" : "NFC write"
            band.linkBracelet(on: profile, detail: detail)
        }
    }

    // MARK: - Bracelet facts

    private var linkStatus: (title: String, detail: String, linked: Bool) {
        if profile.showsBraceletAsLinked {
            return ("Linked bracelet", "Re-write after you edit RedMed", true)
        }
        if profile.braceletLinked {
            return ("Band written", "Finish name, birth date, and blood type on RedMed", false)
        }
        return ("Not linked", "Write once to set up the bracelet", false)
    }

    private var factsCard: some View {
        let rf = AppConfig.BraceletRF.self
        let status = linkStatus
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: status.linked ? "checkmark.seal.fill" : "link")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(status.linked ? .redmedAccent : .redmedMuted)
                    .frame(width: 28, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.redmedDark)
                    Text(status.detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            thinRule

            factRow(icon: "cpu", text: rf.chipSpecSummary)
            thinRule
            factRow(icon: "textformat", text: rf.laserFaceSummary)
            thinRule
            factRow(icon: "hand.point.up.left.fill", text: rf.tapDistanceSummary)
            thinRule
            factRow(icon: "iphone.radiowaves.left.and.right", text: rf.powerOnTapSummary)
            thinRule
            factRow(icon: "lock.open.fill", text: rf.backgroundTagReadingSummary)
            thinRule
            factRow(icon: "person.2.fill", text: rf.passerbyTapSummary)
        }
        .redmedBox()
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Set up")

            PrimaryButton(
                title: writeButtonTitle,
                systemImage: band.isWriting ? nil : "wave.3.right",
                busy: band.isWriting,
                disabled: !profile.hasData || band.isBusy
            ) {
                band.writeBand(from: profile, isScannerSession: isScannerSession)
            }

            if !profile.hasData {
                Text("Add your name on RedMed before writing the band.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
            }

            if !band.statusMessage.isEmpty {
                Text(band.statusMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusIsError ? .redmedAccent : .redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                tipRow("Write once after RedMed is filled — blank unlocked NXP NTAG216 (ISO 14443A Type 2).")
                tipRow("Write packs #d= onto the chip only — never a vendor cloud or social/short link.")
                tipRow("Tap to scan: same HTML card helpers get — quick, no login, no server, no app.")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .redmedBox()
    }

    // MARK: - First-responder Preview (under Write box)

    /// Same card chrome as SET UP — Preview sits even with the rest of the page.
    private var firstResponderPreviewLink: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Preview")

            Text("What first responders see when they tap your band.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            OutlineButton(
                title: "Preview",
                disabled: !profile.hasData || band.isBusy || previewSession != nil
            ) {
                openFirstResponderPreview()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .redmedBox()
    }

    /// Pack `#d=` + embed JSON **before** presenting so the cover is never empty.
    /// `fullScreenCover(item:)` binds the complete session (no isPresented race).
    private func openFirstResponderPreview() {
        guard !isScannerSession, profile.hasData, previewSession == nil else { return }
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        let linked = profile.showsBraceletAsLinked
        // AES pack is tiny (profile-scale) — do it off-main, then present once ready.
        Task { @MainActor in
            let packed = await Task.detached(priority: .userInitiated) {
                (
                    ProfileNFCCodec.previewPayload(from: chip)
                        ?? ProfileNFCCodec.placeholderPreviewPayload,
                    ProfileNFCCodec.embedProfileJSON(from: chip)
                )
            }.value
            guard previewSession == nil else { return }
            previewSession = PreviewSession(
                payload: packed.0,
                embedJSON: packed.1,
                linked: linked
            )
        }
    }

    // MARK: - Pieces

    private var writeButtonTitle: String {
        if band.isWriting {
            return "Hold near the band…"
        }
        return "Write the band"
    }

    private var statusIsError: Bool {
        let msg = band.statusMessage
        if msg.contains("Couldn't") || msg.contains("failed") || msg.contains("Failed") {
            return true
        }
        return !band.writeSucceeded && !msg.isEmpty && !band.isWriting
            && msg != "Hold your iPhone near the NFC tag."
    }

    private var thinRule: some View {
        Divider().overlay(Color.redmedDivider)
    }

    @ViewBuilder
    private func factRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.redmedAccent)
                .frame(width: 28, alignment: .center)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedDark)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.redmedAccent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
                .lineSpacing(2)
        }
    }
}
