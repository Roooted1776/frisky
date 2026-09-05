// Owner-only NFC bracelet setup. Ped/EMS scanner shells never mount this tab —
// see ContentView.showsNFC / scannerSafeTab.
// One page: Write + Preview → full-page tap card (what first responders see).
// When `AppConfig.nfcHardwareEnabled` is true, Write starts a CoreNFC
// NDEF session and programs `medicalCardBaseURL#d=` from the live profile.
// Preview packs the live profile into the same tapper card helpers get.
// Linked only after write + matching read-back. Parked (`false`): pack-only
// Write status + Share Band URL + Preview (never flips Linked).
import SwiftUI

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    /// ContentView keep-alive never calls `onDisappear`. HTML cache may warm
    /// while this tab is front — never spawn a WKWebView here (Preview
    /// creates one when opened).
    var isVisible: Bool = true
    /// Owned by ContentView so the NFC tab tap can begin write on the same gesture.
    @ObservedObject var band: NFCBandManager
    @State private var previewSession: PreviewSession?
    /// Parked CoreNFC: packed `medicalCardBaseURL#d=` for Share → Shortcuts / NFC Tools.
    /// Nil until pack finishes; never used to flip Linked.
    @State private var parkedBandURL: String?
    @State private var parkedPackNote: String = ""

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
            PageHelpChrome()

            ScrollView {
                VStack(spacing: 16) {
                    if profile.showsBraceletAsLinked {
                        completeBanner
                            .padding(.top, 4)
                    }
                    factsCard
                        .padding(.top, profile.showsBraceletAsLinked ? 0 : 4)
                    setupCard
                        .padding(.top, 4)
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.visible)
        }
        .fullScreenCover(item: $previewSession) { session in
            PasserbyHTMLCardView(
                payloadOrURL: session.payload,
                braceletLinked: session.linked,
                embedProfileJSON: session.embedJSON
            )
            .environment(\.isScannerSession, true)
            .presentationBackground(Color.redmedBg)
        }
        .fullScreenCover(item: $band.scannedCard) { session in
            PasserbyHTMLCardView(
                payloadOrURL: session.payload,
                braceletLinked: profile.showsBraceletAsLinked,
                embedProfileJSON: session.embedJSON
            )
            .environment(\.isScannerSession, true)
            .presentationBackground(Color.redmedBg)
        }
        .alert("Bracelet", isPresented: Binding(
            get: { band.alertMessage != nil },
            set: { if !$0 { band.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { band.alertMessage = nil }
        } message: {
            Text(band.alertMessage ?? "")
        }
        .task(id: isVisible) {
            // HTML string only, off the main actor. Do not create a WKWebView
            // on this tab — that was the long NFC load.
            // Session cancel on leave is ContentView (owns the band).
            guard isVisible else { return }
            PasserbyHTMLCardView.scheduleShellWarmOnce()
            await refreshParkedBandURL()
        }
        .onChange(of: band.isWriting) { _, writing in
            guard !writing else { return }
            linkBraceletIfVerified()
        }
        .onChange(of: band.writeVerified) { _, verified in
            guard verified, !band.isWriting else { return }
            linkBraceletIfVerified()
        }
    }

    /// Linked only after a matching read-back. Written-but-unverified stays Not linked.
    private func linkBraceletIfVerified() {
        guard band.writeSucceeded, band.writeVerified, AppConfig.nfcHardwareEnabled else { return }
        band.linkBracelet(on: profile, detail: "NFC write verified")
    }

    private var linkStatus: (title: String, detail: String, linked: Bool) {
        if profile.showsBraceletAsLinked {
            return ("Linked Bracelet", "Re-write after you edit RedMed", true)
        }
        if profile.braceletLinked {
            return ("Band Written", "Finish name, birth date, and blood type on RedMed", false)
        }
        return ("Not Linked", "Write once to set up the bracelet", false)
    }

    /// Obvious done state once write + read-back linked the band.
    private var completeBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.redmedAccent)
                .accessibilityHidden(true)
            Text("Setup Complete")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.redmedDark)
            Text("Bracelet linked. Helpers see your card on a tap.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Re-write after you edit RedMed.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.redmedAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .redmedBox()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Setup complete. Bracelet linked. Helpers see your card on a tap. Re-write after you edit RedMed.")
    }

    private var factsCard: some View {
        let rf = AppConfig.BraceletRF.self
        let status = linkStatus
        return VStack(alignment: .leading, spacing: 0) {
            // When linked, the complete banner owns the done signal — keep a
            // compact Linked row here so the facts card still reads as a unit.
            if !status.linked {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "link")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.redmedMuted)
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
            }

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
            thinRule
            factRow(icon: "key.horizontal", text: AppConfig.OwnerBandURI.packingHonestySummary)
        }
        .redmedBox()
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Set Up")

            PrimaryButton(
                title: writeButtonTitle,
                systemImage: band.isWriting ? nil : "wave.3.right",
                busy: band.isWriting,
                disabled: !profile.hasData || band.isBusy,
                flatten: false
            ) {
                band.writeBand(from: profile, isScannerSession: isScannerSession)
            }

            OutlineButton(
                title: "Preview",
                systemImage: "eye",
                disabled: !profile.hasData || band.isBusy || previewSession != nil
            ) {
                openFirstResponderPreview()
            }

            if !AppConfig.nfcHardwareEnabled {
                parkedShareControl
            }

            if !profile.hasData {
                Text("Add your name on RedMed before writing or previewing the band.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
            }

            if !band.statusMessage.isEmpty {
                Text(band.statusMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusIsError ? .redmedAccent : .redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !parkedPackNote.isEmpty {
                Text(parkedPackNote)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                if AppConfig.nfcHardwareEnabled {
                    tipRow("Open NFC (or tap Write) — then hold the band to the top of the phone \(AppConfig.BraceletRF.intentionalTapRangeLabel).")
                    tipRow("Write packs #d= onto the chip only — never a vendor cloud or social/short link.")
                    tipRow("Preview: same HTML card helpers get — quick, no login, no server, no app.")
                    tipRow("Linked only after write + matching read-back.")
                } else {
                    tipRow("CoreNFC write is parked. Share Band URL onto a blank NTAG216 (Shortcuts or NFC Tools).")
                    tipRow("Preview is the same HTML a helper sees. Linked still needs a real NFC write.")
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .redmedBox()
    }

    @ViewBuilder
    private var parkedShareControl: some View {
        if let parkedBandURL {
            ShareLink(item: parkedBandURL) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Share Band URL")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.redmedAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.redmedBg)
                .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous)
                        .strokeBorder(Color.redmedAccent.opacity(0.45), lineWidth: 1.5)
                )
            }
            .disabled(band.isBusy)
            .opacity(band.isBusy ? 0.72 : 1)
            .accessibilityLabel("Share Band URL")
            .accessibilityHint("Same #d= URL CoreNFC Write would put on a blank NTAG216. Shortcuts or NFC Tools can write it. Does not mark Linked.")
        }
    }

    private func refreshParkedBandURL() async {
        guard !AppConfig.nfcHardwareEnabled, profile.hasData else {
            parkedBandURL = nil
            parkedPackNote = ""
            return
        }
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        let packed = await Task.detached(priority: .userInitiated) {
            ProfileNFCCodec.buildURLString(chip: chip)
        }.value
        guard let packed, AppConfig.OwnerBandURI.isValidWriteURL(packed) else {
            parkedBandURL = nil
            parkedPackNote = "Couldn't pack a RedMed #d= URL."
            return
        }
        if packed.utf8.count > 850 {
            parkedBandURL = nil
            parkedPackNote = "\(packed.utf8.count) bytes — too large for NXP NTAG216. Shorten RedMed."
            return
        }
        parkedPackNote = ""
        parkedBandURL = packed
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
            return AppConfig.nfcHardwareEnabled ? "Hold Near The Band…" : "Packing…"
        }
        // Parked Write packs only — Preview is the single helper-card button.
        return AppConfig.nfcHardwareEnabled ? "Write The Band" : "Pack Band URL"
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
