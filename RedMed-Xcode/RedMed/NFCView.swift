// Owner-only NFC bracelet setup. Ped/EMS scanner shells never mount this tab —
// see ContentView.showsNFC / scannerSafeTab.
import SwiftUI
import CoreNFC

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @StateObject private var writer = NFCWriter()
    @StateObject private var reader = NFCReader()
    @State private var showPublicCard = false
    @State private var scannedCard: ProfileData?
    @State private var showAuthFailedAlert = false
    @State private var statusAlert: String?

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
                    Text("iPhone only for setup. Fill RedMed, write the band once — Face ID, then hold to pair. No Bluetooth; the band stays passive.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 275)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    let capacity = ProfileNFCCodec.capacityNote(for: profile)
                    VStack(spacing: 0) {
                        statusRow("Passive band · 13.56 MHz HF NFC (NTAG) — not Bluetooth 2.4 GHz.", showDivider: true)
                        statusRow("Phone only powers the chip on write/scan. No background pair radio.", showDivider: true)
                        statusRow("Tap the band · phone opens your card · no app for readers", showDivider: true)
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
                                Text(writer.isWriting ? "Hold near tag…" : "Write to NFC tag")
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
                        .disabled(!profile.hasData || writer.isWriting)
                        .opacity(profile.hasData ? 1 : 0.55)
                        if !profile.hasData {
                            Text("Add your name on RedMed before writing a tag.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.redmedAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !writer.statusMessage.isEmpty {
                            Text(writer.statusMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(writer.success ? .redmedMuted : .redmedAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            syncBullet("Link your bracelet once (write after RedMed is filled).")
                            syncBullet("Save after every edit and hold your phone to the band when prompted.")
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
                            Text("Scan your band to see the same emergency card a stranger gets — no app required for them.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .lineSpacing(3)
                            SecondaryButton("Scan your bracelet", icon: "qrcode.viewfinder") { beginScanVerify() }
                            if reader.isReading {
                                Text(reader.statusMessage.isEmpty ? "Hold near tag…" : reader.statusMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.redmedMuted)
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("NFC Bracelet").font(.system(size: 17, weight: .semibold)).foregroundColor(.redmedDark)
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
                guard ok else { return }
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

    func beginWrite() {
        guard !isScannerSession else { return }
        guard profile.hasData else { return }
        guard let url = ProfileNFCCodec.buildURL(profile: profile) else {
            statusAlert = "Couldn't build tag payload from RedMed."
            return
        }
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to write your RedMed card to the bracelet."
        ) { success in
            if success {
                writer.writeURL(url.absoluteString)
            } else {
                showAuthFailedAlert = true
            }
        }
    }

    func beginScanVerify() {
        reader.readTag(alertMessage: "Hold your iPhone near the bracelet to verify the card.") { chip, _ in
            let card = ProfileData(persisting: false)
            ProfileNFCCodec.apply(chip, to: card)
            scannedCard = card
            showPublicCard = true
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
