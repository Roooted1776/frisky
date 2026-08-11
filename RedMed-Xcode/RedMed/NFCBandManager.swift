import Combine
import Foundation
import SwiftUI

/// Drop-in SwiftUI manager for the silicone NFC band pipeline:
///
/// ```
/// [Silicone NFC Band] ──(Tap)──> [iPhone Antenna]
///        ──> [CoreNFC] ──> strip NDEF URI ──> [CryptoKit AES-GCM]
///        ──> [Local app screen]
/// ```
///
/// Owns hardware write/read sessions (`NFCWriter` / `NFCReader`), NDEF URI
/// envelope handling (`NFCURICodec`), and CryptoKit pack/unpack
/// (`ProfileNFCCodec`). No network — chip bytes stay on device. Owner NFC tab
/// only; scanners never mount this manager for setup.
final class NFCBandManager: ObservableObject {
    @Published var statusMessage: String = ""
    @Published var isWriting = false
    @Published var isReading = false
    @Published var writeSucceeded = false
    @Published var writeVerified = false
    @Published var lastPackedURL: String?
    @Published var scannedCard: ProfileData?
    @Published var showScannedCard = false
    @Published var authFailed = false
    @Published var alertMessage: String?

    private let writer = NFCWriter()
    private let reader = NFCReader()
    private var cancellables = Set<AnyCancellable>()

    var isBusy: Bool { isWriting || isReading }

    init() {
        bindSessions()
    }

    // MARK: - Write (owner band setup)

    /// Face ID → AES-GCM pack → CoreNFC write (or simulate when hardware is parked).
    func writeBand(from profile: ProfileData, isScannerSession: Bool) {
        guard !isScannerSession else { return }
        guard profile.hasData else { return }
        guard let urlString = ProfileNFCCodec.buildURLString(profile: profile) else {
            alertMessage = "Couldn't build tag payload from RedMed."
            return
        }

        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to write your RedMed card to the bracelet."
        ) { [weak self] success in
            guard let self else { return }
            if success {
                if AppConfig.nfcHardwareEnabled {
                    self.statusMessage = ""
                    self.writeSucceeded = false
                    self.writeVerified = false
                    self.writer.writeURL(urlString)
                } else {
                    self.simulateWrite(urlString, profile: profile)
                }
            } else {
                self.authFailed = true
            }
        }
    }

    // MARK: - Verify / scan (local card screen)

    /// Hardware path: CoreNFC → strip NDEF → CryptoKit decrypt → local snapshot card.
    /// Simulate path: pack live RedMed → round-trip decode → same card sheet.
    func verifyBand(from profile: ProfileData) {
        if AppConfig.nfcHardwareEnabled {
            statusMessage = ""
            reader.readTag(alertMessage: "Hold your iPhone near the bracelet to verify the card.") { [weak self] chip, _ in
                self?.presentLocalCard(from: chip)
            }
            return
        }

        guard let source = ProfileNFCCodec.buildURLString(profile: profile),
              let chip = ProfileNFCCodec.decodeProfile(fromURLString: source) else {
            alertMessage = "Couldn't pack or decode the get.html#d= payload from RedMed."
            return
        }
        presentLocalCard(from: chip)
    }

    func dismissScannedCard() {
        showScannedCard = false
        scannedCard = nil
    }

    /// Mark owner bracelet paired after a verified (or simulated) write.
    func linkBracelet(on profile: ProfileData, detail: String) {
        // Publishes + Keychain so Main's paired line flips immediately.
        profile.setBraceletPaired(true)
        VaultHistoryStore.shared.record(.braceletWritten, detail: detail)
    }

    // MARK: - Private

    private func bindSessions() {
        writer.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        reader.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        writer.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.isWriting = self.writer.isWriting
                self.writeSucceeded = self.writer.success
                self.writeVerified = self.writer.verified
                if self.writer.isWriting || self.statusMessage.isEmpty || msg != "Cancelled." {
                    self.statusMessage = msg
                }
                if !self.writer.isWriting, !self.writer.success, !msg.isEmpty, msg != "Cancelled." {
                    self.alertMessage = msg
                }
            }
            .store(in: &cancellables)

        writer.$isWriting
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWriting)

        writer.$success
            .combineLatest(writer.$verified)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] success, verified in
                self?.writeSucceeded = success
                self?.writeVerified = verified
            }
            .store(in: &cancellables)

        reader.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.isReading = self.reader.isReading
                if self.reader.isReading {
                    self.statusMessage = msg
                } else if !msg.isEmpty, msg != "Cancelled." {
                    self.alertMessage = msg
                }
            }
            .store(in: &cancellables)

        reader.$isReading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isReading)
    }

    private func simulateWrite(_ urlString: String, profile: ProfileData) {
        isWriting = true
        writeSucceeded = false
        writeVerified = false
        statusMessage = "Packing compact get.html#d= payload…"
        lastPackedURL = urlString
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            let note = ProfileNFCCodec.capacityNote(for: profile)
            self.linkBracelet(on: profile, detail: "Simulated write")
            self.isWriting = false
            self.writeSucceeded = true
            self.writeVerified = true
            self.statusMessage = note.warn
                ? "Simulated write OK — \(note.text)"
                : "Simulated write OK — \(note.text). Open URL below or Simulate scan."
        }
    }

    private func presentLocalCard(from chip: NFCChipProfile) {
        let card = ProfileData(persisting: false)
        ProfileNFCCodec.apply(chip, to: card)
        scannedCard = card
        showScannedCard = true
    }
}
