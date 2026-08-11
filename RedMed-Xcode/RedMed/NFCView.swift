// Owner-only NFC bracelet setup. Ped/EMS scanner shells never mount this tab —
// see ContentView.showsNFC / scannerSafeTab.
// When `AppConfig.nfcHardwareEnabled` is false, Write/Scan simulate packing the
// compact get.html#d= URL so the UX works without an Apple NFC entitlement.
// Pipeline (hardware): silicone band tap → CoreNFC → strip NDEF → CryptoKit → local card
// via `NFCBandManager`.
import SwiftUI

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @StateObject private var band = NFCBandManager()

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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.redmedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.redmedDivider, lineWidth: 1))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    let capacity = ProfileNFCCodec.capacityNote(for: profile)
                    let rf = AppConfig.BraceletRF.self
                    VStack(spacing: 0) {
                        statusRow(rf.carrierVsBluetoothSummary, showDivider: true)
                        statusRow(rf.tapDistanceSummary, showDivider: true)
                        if AppConfig.nfcHardwareEnabled {
                            statusRow(rf.powerOnTapSummary, showDivider: true)
                        }
                        statusRow(rf.passerbyTapSummary, showDivider: true)
                        statusRow(
                            profile.showsBraceletAsLinked
                                ? "Bracelet linked — re-write after you edit RedMed"
                                : profile.braceletLinked
                                    ? "Band written — finish name, birth date, and blood type on RedMed"
                                    : "Bracelet not linked yet — write once to set up",
                            showDivider: true
                        )
                        statusRow(capacity.text, showDivider: false)
                    }
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.redmedDivider, lineWidth: 1))

                    sectionLabel("Set up")
                    VStack(spacing: 12) {
                        Button {
                            band.writeBand(from: profile, isScannerSession: isScannerSession)
                        } label: {
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
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: Color.redmedAccent.opacity(0.28), radius: 7, y: 4)
                        }
                        .disabled(!profile.hasData || band.isBusy)
                        .opacity(profile.hasData ? 1 : 0.55)
                        if !profile.hasData {
                            Text("Add your name on RedMed before writing a tag.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.redmedAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !band.statusMessage.isEmpty {
                            Text(band.statusMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(statusIsError ? .redmedAccent : .redmedMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            syncBullet("Link your bracelet once (write after RedMed is filled).")
                            syncBullet("Payload targets get.html — short path for NTAG213 URI budgets.")
                            syncBullet("After write, linked when read-back matches (or simulate succeeds). Use Preview scanner on RedMed to see the passerby card.")
                            syncBullet("If you cancel the NFC prompt, the band stays stale until you write again.")
                        }
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.redmedDivider, lineWidth: 1))
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
                    Text("NFC Bracelet").font(RedMedChrome.navTitleFont).foregroundColor(.redmedAccent)
                }
            }
            .sheet(isPresented: $band.showScannedCard) {
                if let card = band.scannedCard {
                    PublicCardView(profile: card)
                }
            }
            .alert("Authentication Failed", isPresented: $band.authFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Face ID or passcode is required to write your emergency card to the bracelet.")
            }
            .alert("NFC", isPresented: Binding(
                get: { band.alertMessage != nil },
                set: { if !$0 { band.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { band.alertMessage = nil }
            } message: {
                Text(band.alertMessage ?? "")
            }
            .onChange(of: band.writeVerified) { _, verified in
                guard verified, band.writeSucceeded, AppConfig.nfcHardwareEnabled else { return }
                band.linkBracelet(on: profile, detail: "NFC write verified")
            }
        }
    }

    private var writeButtonTitle: String {
        if band.isWriting {
            return AppConfig.nfcHardwareEnabled ? "Hold near tag…" : "Packing URL…"
        }
        return AppConfig.nfcHardwareEnabled ? "Write to NFC tag" : "Setup"
    }

    private var statusIsError: Bool {
        let msg = band.statusMessage
        if msg.contains("Couldn't") || msg.contains("failed") || msg.contains("Failed") {
            return true
        }
        return !band.writeSucceeded && !msg.isEmpty && !band.isWriting
            && msg != "Hold your iPhone near the NFC tag."
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
