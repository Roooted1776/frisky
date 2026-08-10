// Parked: not in the Xcode target. NFC Tag Reading needs a paid Apple Developer
// Program membership. Restore via RedMed-Xcode/NFC-RESTORE.md when ready.
import SwiftUI
import CoreNFC

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @State private var showWriteOverlay = false
    @State private var writeSuccess = false
    @State private var writeError: String? = nil
    @State private var showPublicCard = false

    var body: some View {
        // Ped/EMS scanner shells must never write or pair bands.
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

                    // STATUS
                    VStack(spacing: 0) {
                        statusRow("Tap the band · phone opens your card · no app for readers", showDivider: true)
                        statusRow("Tag capacity: 24% used — plenty of room", showDivider: false)
                    }
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.redmedDivider, lineWidth: 1))

                    // SET UP
                    sectionLabel("Set up")
                    VStack(spacing: 12) {
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
                        VStack(alignment: .leading, spacing: 6) {
                            syncBullet("Link your bracelet once (My ID → bracelet icon → write/read).")
                            syncBullet("Save after every edit and hold your phone to the band when prompted.")
                            syncBullet("If you cancel the NFC prompt, the band stays stale until you save again.")
                        }
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))

                    // VERIFY
                    sectionLabel("Verify")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan your band to see the same emergency card a stranger gets — no app required for them.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .lineSpacing(3)
                        SecondaryButton("Scan your bracelet", icon: "qrcode.viewfinder") { showPublicCard = true }
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))

                    // IMPORT
                    sectionLabel("Import")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Already own a written tag? Pull it onto this phone's My ID.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .lineSpacing(3)
                        SecondaryButton("Import tag onto this phone", icon: "arrow.down.circle") { profile.name = profile.name.isEmpty ? "Alex Rivera" : profile.name }
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
            .overlay {
                if showWriteOverlay {
                    NFCWriteOverlay(
                        onCancel: { showWriteOverlay = false },
                        onSuccess: {
                            showWriteOverlay = false
                            profile.braceletLinked = true
                        }
                    )
                }
            }
            .sheet(isPresented: $showPublicCard) { PublicCardView(profile: profile) }
        }
    }

    func beginWrite() {
        guard !isScannerSession else { return }
        guard profile.hasData else { return }
        // In production: LAContext biometric auth, then NFCNDEFWriterSession
        // Do not mark braceletLinked until write succeeds (or demo completes).
        showWriteOverlay = true
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
    let onSuccess: () -> Void

    @State private var demoTask: Task<Void, Never>?

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

                Button {
                    demoTask?.cancel()
                    demoTask = nil
                    onCancel()
                } label: {
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
        .onAppear {
            // Demo stub: simulate a completed NFC write after a short hold.
            // Cancel / disappear before this fires leaves braceletLinked unchanged.
            demoTask?.cancel()
            demoTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                onSuccess()
            }
        }
        .onDisappear {
            demoTask?.cancel()
            demoTask = nil
        }
    }
}
