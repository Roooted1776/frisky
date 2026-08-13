// Owner-only NFC bracelet setup. Ped/EMS scanner shells never mount this tab —
// see ContentView.showsNFC / scannerSafeTab.
// One page: Write (passive rewritable Type 2 / NTAG) + Scan → full-page tap card.
// When `AppConfig.nfcHardwareEnabled` is true, Write/Scan start real CoreNFC
// sessions. Simulate packing stays as the offline/dev fallback when the flag is off.
// Pipeline (hardware): silicone band tap → CoreNFC → strip NDEF → CryptoKit → local card
// via `NFCBandManager`.
import SwiftUI

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @StateObject private var band = NFCBandManager()

    private let boxRadius = RedMedChrome.boxRadius

    var body: some View {
        if isScannerSession {
            Color.redmedBg.ignoresSafeArea()
        } else {
            ownerBody
        }
    }

    private var ownerBody: some View {
        // Fixed cream chrome (no NavigationView / system toolbar) — page
        // BrandWordmark (911 / Aid are content-first; pane wordmarks only).
        // Owner-only tab; scanners never mount this.
        VStack(spacing: 0) {
            BrandWordmarkHeader()

            ScrollView {
                VStack(spacing: 16) {
                    factsCard
                    setupCard
                    scanCard
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.visible)
        }
        .background { RedMedPageBackground() }
        // Same one-page tap card as RedMed Preview / a real band tap.
        .fullScreenCover(isPresented: $band.showScannedCard) {
            if let payload = band.scannedHTMLPayload {
                PasserbyHTMLCardView(
                    payloadOrURL: payload,
                    braceletLinked: profile.showsBraceletAsLinked
                )
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

    // MARK: - Bracelet facts

    private var linkStatus: (title: String, detail: String, linked: Bool) {
        if profile.showsBraceletAsLinked {
            return ("Linked", "Re-write after you edit RedMed", true)
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

            factRow(icon: "hand.point.up.left.fill", text: rf.tapDistanceSummary)
            thinRule
            factRow(icon: "iphone.radiowaves.left.and.right", text: rf.powerOnTapSummary)
            thinRule
            factRow(icon: "person.2.fill", text: rf.passerbyTapSummary)
        }
        .redmedBox()
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SET UP")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(.redmedMuted)

            Button {
                band.writeBand(from: profile, isScannerSession: isScannerSession)
            } label: {
                HStack(spacing: 8) {
                    if band.isWriting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "wave.3.right")
                    }
                    Text(writeButtonTitle)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1, green: 0.447, blue: 0.537), .redmedAccent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: boxRadius))
                .shadow(color: Color.redmedAccent.opacity(profile.hasData ? 0.28 : 0), radius: 7, y: 4)
            }
            .disabled(!profile.hasData || band.isBusy)
            .opacity(profile.hasData ? 1 : 0.55)

            if !profile.hasData {
                Text("Add your name on RedMed before writing a tag.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.redmedAccent)
            }

            if !band.statusMessage.isEmpty {
                Text(band.statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(statusIsError ? .redmedAccent : .redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                tipRow("Write once after RedMed is filled — blank rewritable Type 2 (NTAG) band.")
                tipRow("Write packs #d= onto the chip only — never a vendor cloud or social/short link.")
                tipRow("Tap to scan: same HTML card helpers get — quick, no login, no server, no app.")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .redmedBox()
    }

    // MARK: - Scan (bottom of page)

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCAN")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(.redmedMuted)

            if profile.braceletLinked {
                Text(AppConfig.nfcHardwareEnabled
                      ? "Tap to scan: hold near the band — card opens in their browser. Quick. No login. No server. No app."
                      : "Simulate scan opens the same tap card helpers get — quick, no login, no server, no app.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    band.verifyBand(from: profile)
                } label: {
                    HStack(spacing: 8) {
                        if band.isReading {
                            ProgressView().tint(.redmedAccent)
                        } else {
                            Image(systemName: "wave.3.right.circle")
                        }
                        Text(scanButtonTitle)
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.redmedAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.redmedBg)
                    .clipShape(RoundedRectangle(cornerRadius: boxRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: boxRadius)
                            .strokeBorder(Color.redmedAccent.opacity(0.45), lineWidth: 1.5)
                    )
                }
                .disabled(band.isBusy)
                .buttonStyle(.plain)

                if band.isReading, !band.statusMessage.isEmpty {
                    Text(band.statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.redmedMuted)
                }
            } else {
                Text(AppConfig.nfcHardwareEnabled
                      ? "Write above first — then Scan here for the same tap card helpers see."
                      : "Write above first — then Simulate scan here for the tap card helpers see.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .redmedBox()
    }

    // MARK: - Pieces

    private var writeButtonTitle: String {
        if band.isWriting {
            return AppConfig.nfcHardwareEnabled ? "Hold near tag…" : "Packing…"
        }
        return AppConfig.nfcHardwareEnabled ? "Write to NFC tag" : "Setup"
    }

    private var scanButtonTitle: String {
        if band.isReading {
            return AppConfig.nfcHardwareEnabled ? "Hold near tag…" : "Opening…"
        }
        return AppConfig.nfcHardwareEnabled ? "Scan your bracelet" : "Simulate scan"
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedMuted)
                .lineSpacing(2)
        }
    }
}
