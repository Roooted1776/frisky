// Owner-only NFC bracelet setup. Ped/EMS scanner shells never mount this tab —
// see ContentView.showsNFC / scannerSafeTab.
// One page: Write + Scan + Preview → full-page tap card (what first responders see).
// When `AppConfig.nfcHardwareEnabled` is true, Write/Scan start real CoreNFC.
// Pack-only simulate stays when the flag is off — it never flips Linked.
import SwiftUI

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @StateObject private var band = NFCBandManager()
    @State private var previewSession: PreviewSession?

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
        VStack(spacing: 0) {
            BrandWordmarkHeader()
                .redmedTopChromeFill()

            ScrollView {
                VStack(spacing: 16) {
                    if !AppConfig.nfcHardwareEnabled {
                        parkedBanner
                    }
                    factsCard
                    setupCard
                        .padding(.top, 4)
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
        .fullScreenCover(item: $band.scannedCard) { session in
            PasserbyHTMLCardView(
                payloadOrURL: session.payload,
                braceletLinked: profile.showsBraceletAsLinked,
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
        .onChange(of: band.isWriting) { _, writing in
            guard !writing, band.writeSucceeded, AppConfig.nfcHardwareEnabled else { return }
            let detail = band.writeVerified ? "NFC write verified" : "NFC write"
            band.linkBracelet(on: profile, detail: detail)
        }
    }

    private var linkStatus: (title: String, detail: String, linked: Bool) {
        if profile.showsBraceletAsLinked {
            return ("Linked bracelet", "Re-write after you edit RedMed", true)
        }
        if profile.braceletLinked {
            return ("Band written", "Finish name, birth date, and blood type on RedMed", false)
        }
        return ("Not linked", "Write once to set up the bracelet", false)
    }

    private var parkedBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview only")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.redmedAccent)
            Text(AppConfig.BraceletRF.hardwareParkedSummary)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .redmedBox()
        .accessibilityLabel("Band write is preview-only in this build")
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

            OutlineButton(
                title: band.isReading ? "Opening…" : "Scan",
                disabled: !profile.hasData || band.isBusy || band.scannedCard != nil
            ) {
                band.verifyBand(from: profile)
            }

            if !profile.hasData {
                Text("Add your name on RedMed before writing or scanning the band.")
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
                if AppConfig.nfcHardwareEnabled {
                    tipRow("Write once after RedMed is filled — blank unlocked NXP NTAG216 (ISO 14443A Type 2).")
                    tipRow("Write packs #d= onto the chip only — never a vendor cloud or social/short link.")
                    tipRow("Scan / Preview: same HTML card helpers get — quick, no login, no server, no app.")
                } else {
                    tipRow("This build cannot write a physical band (NFC Tag Reading is parked).")
                    tipRow("Preview packed card opens the same HTML helpers would see — no Linked flag.")
                    tipRow("Live write ships when NFC Tag Reading is on the App ID. See docs/NFC-RESTORE.md.")
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .redmedBox()
    }

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

            if !profile.hasData {
                Text("Add your name on RedMed before previewing the band.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .redmedBox()
    }

    private func openFirstResponderPreview() {
        guard !isScannerSession, profile.hasData, previewSession == nil else { return }
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        let linked = profile.showsBraceletAsLinked
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

    private var writeButtonTitle: String {
        if band.isWriting {
            return AppConfig.nfcHardwareEnabled ? "Hold near the band…" : "Packing…"
        }
        return AppConfig.nfcHardwareEnabled ? "Write the band" : "Preview packed card"
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
