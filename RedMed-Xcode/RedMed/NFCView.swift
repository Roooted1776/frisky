// Owner-only NFC bracelet setup. Ped/EMS scanner shells never mount this tab —
// see ContentView.showsNFC / scannerSafeTab.
// When `AppConfig.nfcHardwareEnabled` is false, Write/Scan simulate packing the
// compact get.html#d= URL so the UX works without an Apple NFC entitlement.
import SwiftUI

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @StateObject private var writer = NFCWriter()
    @StateObject private var reader = NFCReader()
    @State private var showPublicCard = false
    @State private var scannedCard: ProfileData?
    @State private var showAuthFailedAlert = false
    @State private var statusAlert: String?
    @State private var simulateBusy = false
    @State private var simulateMessage = ""
    @State private var lastSimulatedURL: String?

    var body: some View {
        if isScannerSession {
            Color.redmedBg.ignoresSafeArea()
        } else {
            ownerBody
        }
    }

    private var ownerBody: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    Text(AppConfig.nfcHardwareEnabled
                          ? "iPhone only for setup. Fill RedMed, write the band once — Face ID, then hold to pair. No Bluetooth; the band stays passive."
                          : "Simulate band setup while learning (no Apple NFC entitlement yet). Write packs the same compact get.html#d= URL a real NTAG213 would hold.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 275)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    let capacity = ProfileNFCCodec.capacityNote(for: profile)
                    let rf = AppConfig.BraceletRF.self
                    VStack(spacing: 0) {
                        statusRow(rf.carrierVsBluetoothSummary, showDivider: true)
                        statusRow("Compact `#d=`: flat array → AES-GCM → Base64url → get.html", showDivider: true)
                        statusRow(rf.tapDistanceSummary, showDivider: true)
                        statusRow(
                            AppConfig.nfcHardwareEnabled
                                ? rf.powerOnTapSummary
                                : "Hardware NFC parked — simulate write packs the URL; flip AppConfig + entitlements to go live.",
                            showDivider: true
                        )
                        statusRow(rf.passerbyTapSummary, showDivider: true)
                        statusRow(
                            profile.braceletLinked
                                ? "Bracelet linked — re-write after you edit RedMed"
                                : "Bracelet not linked yet — write once to pair",
                            showDivider: true
                        )
                        statusRow(capacity.text, showDivider: false)
                    }
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.redmedDivider, lineWidth: 1))

                    sectionLabel("Set up")
                    VStack(spacing: 12) {
                        Button { beginWrite() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wave.3.right")
                                Text(writeButtonTitle)
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                LinearGradient(colors: [Color(red:1, green:0.447, blue:0.537), .redmedAccent],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.redmedAccent.opacity(0.28), radius: 7, y: 4)
                        }
                        .disabled(!profile.hasData || writer.isWriting || simulateBusy)
                        .opacity(profile.hasData ? 1 : 0.55)
                        if !profile.hasData {
                            Text("Add your name on RedMed before writing a tag.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.redmedAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !statusLine.isEmpty {
                            Text(statusLine)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(statusIsError ? .redmedAccent : .redmedMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            syncBullet("Link your bracelet once (write after RedMed is filled).")
                            syncBullet("Payload targets get.html — short path for NTAG213 URI budgets.")
                            syncBullet("After write, Scan below — linked only when read-back matches (or simulate succeeds).")
                            syncBullet("If you cancel the NFC prompt, the band stays stale until you write again.")
                        }
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))

                    sectionLabel("Verify")
                    VStack(alignment: .leading, spacing: 12) {
                        if profile.braceletLinked {
                            Text(AppConfig.nfcHardwareEnabled
                                  ? "Scan your band to see the same emergency card a stranger gets — no app required for them."
                                  : "Simulate scan to preview the passerby shell (same as get.html after a tap).")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .lineSpacing(3)
                            SecondaryButton(
                                AppConfig.nfcHardwareEnabled ? "Scan your bracelet" : "Simulate scan (passerby view)",
                                icon: "qrcode.viewfinder"
                            ) { beginScanVerify() }
                            if reader.isReading {
                                Text(reader.statusMessage.isEmpty ? "Hold near tag…" : reader.statusMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.redmedMuted)
                            }
                            if let url = lastSimulatedURL, let link = URL(string: url) {
                                Link("Open packed get.html URL", destination: link)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.redmedAccent)
                            }
                        } else {
                            Text("Write the band once above — then you can scan to verify the tap card.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .lineSpacing(3)
                        }
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.redmedBg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.redmedBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("NFC Bracelet").font(.system(size: 17, weight: .semibold)).foregroundColor(.redmedAccent)
                }
            }
            .sheet(isPresented: $showPublicCard) {
                if let card = scannedCard {
                    PublicCardView(profile: card)
                }
            }
            .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Face ID or passcode is required to write your emergency card to the bracelet.")
            }
            .alert("NFC", isPresented: Binding(
                get: { statusAlert != nil },
                set: { if !$0 { statusAlert = nil } }
            )) {
                Button("OK", role: .cancel) { statusAlert = nil }
            } message: {
                Text(statusAlert ?? "")
            }
            .onChange(of: writer.success) { _, ok in
                guard ok, writer.verified else { return }
                profile.braceletLinked = true
                profile.persist()
            }
            .onChange(of: writer.verified) { _, verified in
                guard verified, writer.success else { return }
                profile.braceletLinked = true
                profile.persist()
            }
            .onChange(of: writer.statusMessage) { _, msg in
                if !writer.isWriting, !writer.success, !msg.isEmpty, msg != "Cancelled." {
                    statusAlert = msg
                }
            }
            .onChange(of: reader.statusMessage) { _, msg in
                if !reader.isReading, !msg.isEmpty, msg != "Cancelled." {
                    statusAlert = msg
                }
            }
        }
    }

    private var writeButtonTitle: String {
        if writer.isWriting || simulateBusy {
            return AppConfig.nfcHardwareEnabled ? "Hold near tag…" : "Packing URL…"
        }
        return AppConfig.nfcHardwareEnabled ? "Write to NFC tag" : "Simulate write (pack get.html URL)"
    }

    private var statusLine: String {
        if !simulateMessage.isEmpty { return simulateMessage }
        return writer.statusMessage
    }

    private var statusIsError: Bool {
        if !simulateMessage.isEmpty {
            return simulateMessage.contains("Couldn't") || simulateMessage.contains("failed")
        }
        return !writer.success && !writer.statusMessage.isEmpty
    }

    func beginWrite() {
        guard !isScannerSession else { return }
        guard profile.hasData else { return }
        guard let urlString = ProfileNFCCodec.buildURLString(profile: profile) else {
            statusAlert = "Couldn't build tag payload from RedMed."
            return
        }

        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to write your RedMed card to the bracelet."
        ) { success in
            if success {
                if AppConfig.nfcHardwareEnabled {
                    // Drop stale simulate copy so NFCWriter progress/errors are visible.
                    simulateBusy = false
                    simulateMessage = ""
                    writer.writeURL(urlString)
                } else {
                    simulateWrite(urlString)
                }
            } else {
                showAuthFailedAlert = true
            }
        }
    }

    func beginScanVerify() {
        if AppConfig.nfcHardwareEnabled {
            simulateBusy = false
            simulateMessage = ""
            reader.readTag(alertMessage: "Hold your iPhone near the bracelet to verify the card.") { chip, _ in
                let card = ProfileData(persisting: false)
                ProfileNFCCodec.apply(chip, to: card)
                scannedCard = card
                showPublicCard = true
            }
            return
        }
        // Always pack the live RedMed profile (same as Preview scanner). Do not
        // reuse lastSimulatedURL — that stays as the last “written” URL link only.
        // Fail if pack/decode breaks — never present the editor profile as a
        // successful `#d=` round-trip.
        guard let source = ProfileNFCCodec.buildURLString(profile: profile),
              let chip = ProfileNFCCodec.decodeProfile(fromURLString: source) else {
            statusAlert = "Couldn't pack or decode the get.html#d= payload from RedMed."
            return
        }
        let card = ProfileData(persisting: false)
        ProfileNFCCodec.apply(chip, to: card)
        scannedCard = card
        showPublicCard = true
    }

    private func simulateWrite(_ urlString: String) {
        simulateBusy = true
        simulateMessage = "Packing compact get.html#d= payload…"
        lastSimulatedURL = urlString
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let note = ProfileNFCCodec.capacityNote(for: profile)
            profile.braceletLinked = true
            profile.persist()
            simulateBusy = false
            simulateMessage = note.warn
                ? "Simulated write OK — \(note.text)"
                : "Simulated write OK — \(note.text). Open URL below or Simulate scan."
        }
    }

    @ViewBuilder
    func statusRow(_ text: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            if showDivider {
                Divider().overlay(Color.black.opacity(0.06))
            }
        }
    }

    @ViewBuilder
    func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.5)
            .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    func syncBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.redmedAccent)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedMuted)
                .lineSpacing(3)
        }
    }
}
