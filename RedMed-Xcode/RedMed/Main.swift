import SwiftUI

/// Owner app shell — edit profile, Aid treatments, NFC write, Find Help.
/// Product HTML is only the passerby `card.html` + policy pages; those redirect
/// here (`redmed://main`) for owner information.
struct Main: View {
    var body: some View {
        ContentView()
    }
}

/// Converted from former `HowItWorks.html` + `get.html` setup copy.
/// Shown in-app from Help — not as a web shell.
struct MainInfoView: View {
    @Environment(\.dismiss) private var dismiss
    var onOpenNFC: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Fill out your emergency profile once in the app, write it to a passive 13.56 MHz HF NFC bracelet (not Bluetooth), and anyone who taps the band with a phone sees your emergency card — no app or account required on their end.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.redmedAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                section(num: "1", title: "Set up RedMed") {
                    Text("Open the RedMed tab and tap Edit. Unlock with Face ID, Touch ID, or your device passcode when asked. Add your name, birth date, and blood type, then list any allergies, medications, and conditions a first responder should know. Add emergency contacts with phone numbers. Tap Save when done.")
                }

                section(num: "2", title: "Write your bracelet") {
                    Text("Go to the NFC tab and tap Write to NFC tag. Confirm with Face ID, Touch ID, or your passcode, then hold the top of your iPhone near the bracelet when prompted. Your profile is written to the passive chip in the band. Walk-by distance will not fire the band; only a deliberate ~1–2″ antenna tap opens the card.")
                    if AppConfig.nfcHardwareEnabled, let onOpenNFC {
                        Button("Open NFC tab") {
                            dismiss()
                            DispatchQueue.main.async { onOpenNFC() }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.redmedAccent)
                        .padding(.top, 4)
                    }
                }

                section(num: "3", title: "Verify it") {
                    Text("On the NFC tab, tap Scan your bracelet (or use Preview scanner on RedMed) to see the same read-only RedMed / Help / Aid shell a stranger gets. There is no Edit and no NFC write UI in that view.")
                }

                section(num: "4", title: "What a stranger sees") {
                    Text("Anyone who taps the bracelet opens the passerby card page (card.html) with RedMed, Help, and Aid — your profile, Call emergency / GPS help, and roadside aid. No RedMed app or login is required, and they cannot edit your profile or write the band.")
                }

                section(num: "5", title: "In an emergency") {
                    Text("Use the Help tab for one-tap dialing and live GPS coordinates to read off to a dispatcher. Use the Aid tab for step-by-step guidance on bleeding, CPR, shock, and other roadside situations while help is on the way.")
                }

                section(num: "6", title: "Keeping it in sync") {
                    Text("If you edit your profile later, reopen the NFC tab and write to the band again — the bracelet only shows what was last written to it.")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Band setup (3 steps)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.redmedDark)
                    setupStep(1, "Open RedMed on iPhone and fill in your allergies, meds, and contacts.")
                    setupStep(2, "Hold your band to the top of your iPhone once — the chip stores your emergency card.")
                    setupStep(3, "Done. Anyone taps the band — their phone opens emergency call and your critical info. No app needed.")
                    Text("Passive 13.56 MHz HF NFC only — no battery, no Bluetooth pair. RedMed is not a medical device. In an emergency, call your local emergency number.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .padding(.top, 4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.redmedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.redmedDark.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(Color.redmedBg.ignoresSafeArea())
        .navigationTitle("How It Works")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(num: String, title: String, @ViewBuilder body: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(num)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.redmedAccent)
                    .clipShape(Circle())
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.redmedDark)
            }
            body()
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.redmedAccent)
                .frame(width: 22, height: 22)
                .background(Color.redmedAccent.opacity(0.12))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedDark)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
