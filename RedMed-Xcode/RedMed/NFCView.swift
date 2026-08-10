import SwiftUI
import CoreNFC

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @EnvironmentObject var nfc: NFCManager
    @State private var showPublicCard = false
    @State private var scannedProfile: ProfileData?
    @State private var showAuthFailedAlert = false
    @State private var showNeedProfileAlert = false
    @State private var importFlash = false
    @State private var capacityNote: String = "Blank tag — write your My ID to pair"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("NFC Bracelet")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.redmedDark)
                        Text("Blank tags ship empty. Fill My ID, then write once — Face ID, hold to band, done. Readers need no app.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 290)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        statusRow(
                            profile.braceletLinked
                                ? "Bracelet paired · strangers tap to open your card"
                                : "Not paired yet · write your My ID to a blank band",
                            showDivider: true
                        )
                        statusRow(capacityNote, showDivider: false)
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
                                Text(profile.braceletLinked ? "Rewrite NFC tag" : "Write to NFC tag")
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
                        .disabled(!profile.hasData || nfc.isScanning)
                        .opacity(profile.hasData && !nfc.isScanning ? 1 : 0.45)

                        VStack(alignment: .leading, spacing: 6) {
                            syncBullet("Open RedMed → Edit My ID → Save → Write to NFC tag.")
                            syncBullet("Bands ship blank. Your individual info is written at pair time.")
                            syncBullet("After every edit, write again or the band stays stale.")
                        }
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))

                    sectionLabel("Verify")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan your band to see the same emergency card a stranger gets — no app required for them.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .lineSpacing(3)
                        SecondaryButton("Scan your bracelet", icon: "qrcode.viewfinder") {
                            _ = nfc.beginRead(for: .scanPreview)
                        }
                        .disabled(nfc.isScanning)
                        .opacity(nfc.isScanning ? 0.45 : 1)
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))

                    sectionLabel("Import")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Already own a written tag? Pull it onto this phone's My ID.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .lineSpacing(3)
                        SecondaryButton(importFlash ? "Imported ✓" : "Import tag onto this phone",
                                        icon: "arrow.down.circle") {
                            importFlash = false
                            _ = nfc.beginRead(for: .importToPhone)
                        }
                        .disabled(nfc.isScanning)
                        .opacity(nfc.isScanning ? 0.45 : 1)
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
                    .padding(.bottom, 16)

                    if let err = nfc.lastError {
                        Text(err)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
                if nfc.isDemoSession {
                    NFCWriteOverlay { nfc.cancel() }
                }
            }
            .sheet(isPresented: $showPublicCard) {
                if let scanned = scannedProfile {
                    PublicCardView(profile: scanned)
                } else {
                    PublicCardView(profile: profile)
                }
            }
            .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Face ID or passcode is required before writing your medical profile to a bracelet.")
            }
            .alert("Add your My ID first", isPresented: $showNeedProfileAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Open the RedMed tab, tap Edit, and save your name before pairing a blank bracelet.")
            }
            .onChange(of: nfc.lastWriteSucceeded) { _, ok in
                guard ok else { return }
                updateCapacityNote()
            }
            .onChange(of: nfc.lastReadPayload) { _, payload in
                guard let payload else { return }
                let intent = nfc.readIntent
                switch intent {
                case .importToPhone:
                    payload.apply(to: profile, persist: true)
                    importFlash = true
                    nfc.consumeReadResult()
                case .scanPreview:
                    let preview = ProfileData.previewShell()
                    payload.apply(to: preview, persist: false)
                    scannedProfile = preview
                    showPublicCard = true
                    nfc.consumeReadResult()
                case .none:
                    break
                }
            }
            .onChange(of: nfc.tagCapacityBytes) { _, _ in updateCapacityNote() }
            .onChange(of: nfc.lastPayloadBytes) { _, _ in updateCapacityNote() }
            .onAppear {
                if profile.pendingBraceletWrite {
                    profile.pendingBraceletWrite = false
                    beginWrite()
                }
                updateCapacityNote()
            }
            .onChange(of: profile.pendingBraceletWrite) { _, pending in
                if pending {
                    profile.pendingBraceletWrite = false
                    beginWrite()
                }
            }
        }
    }

    private func beginWrite() {
        guard profile.hasData else {
            showNeedProfileAlert = true
            return
        }
        guard !nfc.isScanning else {
            nfc.lastError = "NFC session already in progress. Finish or cancel it first."
            return
        }
        // Snapshot + app-scoped manager: Face ID may finish after leaving this tab.
        let snapshot = CardPayload.from(profile: profile)
        let manager = nfc
        BiometricAuth.authenticate(reason: "Authenticate to write your medical ID to the bracelet.") { success in
            guard success else {
                showAuthFailedAlert = true
                manager.lastError = "Face ID or passcode is required before writing your medical profile to a bracelet."
                return
            }
            do {
                let url = try snapshot.cardURL()
                manager.beginWrite(url: url)
            } catch {
                manager.lastError = "Could not build card URL: \(error.localizedDescription)"
            }
        }
    }

    private func updateCapacityNote() {
        if let used = nfc.lastPayloadBytes, let cap = nfc.tagCapacityBytes, cap > 0 {
            let pct = min(100, (used * 100) / cap)
            capacityNote = "Tag capacity: \(pct)% used (\(used) / \(cap) B)"
        } else if profile.braceletLinked {
            capacityNote = "Paired · rewrite after any My ID edit"
        } else if profile.hasData, let approx = try? CardPayload.from(profile: profile).estimatedNDEFByteCount() {
            capacityNote = "Est. write size ~\(approx) B · NTAG215/216 recommended"
        } else {
            capacityNote = "Blank tag — write your My ID to pair"
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

extension ProfileData {
    /// Ephemeral shell for scan preview — never written back to UserDefaults.
    static func previewShell() -> ProfileData {
        let p = ProfileData()
        p.name = ""
        p.birthDate = ""
        p.bloodType = ""
        p.allergies = []
        p.medications = []
        p.conditions = []
        p.contacts = []
        p.isOrganDonor = false
        p.lastUpdated = ""
        p.braceletLinked = false
        return p
    }
}

// MARK: - Hold-to-band overlay (Simulator / no-hardware demo)

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
