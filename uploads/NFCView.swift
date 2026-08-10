import SwiftUI
import CoreNFC

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @State private var showWriteOverlay = false
    @State private var writeSuccess = false
    @State private var writeError: String? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    VStack(spacing: 4) {
                        Text("NFC Bracelet")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.redmedDark)
                        Text("iPhone only for setup. Fill My ID, write the band once — CoreNFC, Face ID, done.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 275)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                    infoChip("Tap the band · phone opens your card · no app for readers")
                    infoChip("Tag capacity: 24% used — plenty of room")

                    // WRITE BUTTON
                    Button { beginWrite() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wave.3.right")
                            Text("Write to NFC tag")
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
                    .padding(.top, 4)

                    SecondaryButton("Preview hosted card in Safari", icon: "safari") {
                        // Open hosted card URL
                    }

                    // VERIFY CARD
                    VStack(alignment: .leading, spacing: 10) {
                        Text("VERIFY")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(1.1)
                            .foregroundColor(.redmedMuted)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Color.redmedMuted.opacity(0.1)))

                        Text("After writing, scan your band here to see the same emergency card a stranger gets.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .lineSpacing(3)

                        SecondaryButton("Scan your bracelet") { /* CoreNFC read */ }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.redmedDivider, lineWidth: 1))

                    // KEEP IN SYNC
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Keep your band in sync")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.redmedDark)
                        syncBullet("Link your bracelet once (My ID → bracelet icon → write/read).")
                        syncBullet("Save after every edit and hold your phone to the band when prompted.")
                        syncBullet("If you cancel the NFC prompt, the band stays stale until you save again.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.redmedDivider, lineWidth: 1))

                    dividerLabel("SCAN CARD")

                    Text("Optional: scan in RedMed for the native card view. Passersby only need to tap the band — no app.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    SecondaryButton("Scan emergency bracelet", icon: "qrcode.viewfinder") { /* read NFC */ }

                    dividerLabel("OR IMPORT")

                    Text("Already own a written tag? Pull it onto this phone's My ID.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    SecondaryButton("Import tag onto this phone", icon: "arrow.down.circle") { /* import NFC */ }
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
            .overlay {
                if showWriteOverlay { NFCWriteOverlay { showWriteOverlay = false } }
            }
        }
    }

    func beginWrite() {
        guard profile.hasData else { return }
        // In production: LAContext biometric auth, then NFCNDEFWriterSession
        showWriteOverlay = true
    }

    @ViewBuilder
    func infoChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.redmedMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.redmedDivider, lineWidth: 1))
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

    @ViewBuilder
    func dividerLabel(_ text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.redmedDivider).frame(height: 0.5)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .kerning(1)
                .foregroundColor(.redmedMuted)
            Rectangle().fill(Color.redmedDivider).frame(height: 0.5)
        }
    }
}

// MARK: - Write Overlay
struct NFCWriteOverlay: View {
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.redmedAccent.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 104, height: 104)
                    Circle()
                        .fill(Color.redmedAccent.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 32))
                        .foregroundColor(.redmedAccent)
                }

                VStack(spacing: 8) {
                    Text("Hold to band")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Bring the top of your iPhone close to the NFC bracelet")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                        .lineSpacing(3)
                }

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32).padding(.vertical, 13)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
    }
}
