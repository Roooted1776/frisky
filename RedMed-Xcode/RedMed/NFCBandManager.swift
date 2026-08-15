import Combine
import Foundation
import SwiftUI

/// Drop-in SwiftUI manager for the silicone NFC band pipeline:
///
/// ```
/// [Silicone NFC Band] ──(Tap)──> [iPhone Antenna]
///        ──> [CoreNFC] ──> strip NDEF URI ──> [CryptoKit AES-GCM]
///        ──> [tap card HTML shell]
/// ```
///
/// Owns hardware write/read sessions (`NFCWriter` / `NFCReader`), NDEF URI
/// envelope handling (`NFCURICodec`), and CryptoKit pack/unpack
/// (`ProfileNFCCodec`). No network — chip bytes stay on device. Owner NFC tab
/// only; scanners never mount this manager for setup.
/// Band writes use live `AppConfig.medicalCardBaseURL#d=` only (owner data
/// independence: no vendor cloud, no social/short URL, no BLE).
final class NFCBandManager: ObservableObject {
    @Published var statusMessage: String = ""
    @Published var isWriting = false
    @Published var isReading = false
    @Published var writeSucceeded = false
    @Published var writeVerified = false
    @Published var lastPackedURL: String?
    /// `#d=` payload or full band URL for `PasserbyHTMLCardView` (HTML shell).
    @Published var scannedHTMLPayload: String?
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

    /// Face ID → AES-GCM pack (off-main) → CoreNFC write (or simulate when hardware is parked).
    func writeBand(from profile: ProfileData, isScannerSession: Bool) {
        guard !isScannerSession else { return }
        guard profile.hasData else { return }

        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to write your RedMed card to the bracelet."
        ) { [weak self] outcome in
            guard let self else { return }
            if outcome == .success {
                let chip = ProfileNFCCodec.chipProfile(from: profile)
                Task { @MainActor [weak self] in
                    let urlString = await Task.detached(priority: .userInitiated) {
                        ProfileNFCCodec.buildURLString(chip: chip)
                    }.value
                    guard let self else { return }
                    guard let urlString,
                          AppConfig.OwnerBandURI.isValidWriteURL(urlString) else {
                        self.alertMessage = "Couldn't build a RedMed #d= tag payload (vendor/social URLs are blocked)."
                        return
                    }
                    if AppConfig.nfcHardwareEnabled {
                        self.statusMessage = ""
                        self.writeSucceeded = false
                        self.writeVerified = false
                        self.writer.writeURL(urlString)
                    } else {
                        self.simulateWrite(urlString, profile: profile)
                    }
                }
            } else if outcome == .notVerified {
                self.authFailed = true
                VaultHistoryStore.shared.record(.unlockFailed, detail: "nfcWrite")
            }
        }
    }

    // MARK: - Verify / scan (same HTML shell a stranger gets on band tap)

    /// Hardware path: CoreNFC → strip NDEF → open bundled tap card (?src=app, no SOS arm).
    /// Simulate path: pack live RedMed → same one-page HTML cover (tap card).
    /// Hardware sessions gated by `AppConfig.nfcHardwareEnabled`.
    func verifyBand(from profile: ProfileData) {
        if AppConfig.nfcHardwareEnabled {
            statusMessage = ""
            reader.readTag(alertMessage: "Hold your iPhone near the bracelet to verify the card.") { [weak self] _, urlString in
                self?.presentHTMLCard(payloadOrURL: urlString)
            }
            return
        }

        let chip = ProfileNFCCodec.chipProfile(from: profile)
        isReading = true
        statusMessage = "Opening tap card…"
        Task.detached(priority: .userInitiated) {
            let source = ProfileNFCCodec.buildURLString(chip: chip)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isReading = false
                self.statusMessage = ""
                guard let source else {
                    self.alertMessage = "Couldn't pack or decode the tap card from RedMed."
                    return
                }
                self.presentHTMLCard(payloadOrURL: source)
            }
        }
    }

    func dismissScannedCard() {
        showScannedCard = false
        scannedHTMLPayload = nil
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
                    // Status string only — never pack URL / profile fields into the vault.
                    VaultHistoryStore.shared.record(.nfcWriteFailed, detail: String(msg.prefix(120)))
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
        statusMessage = "Packing compact tap card…"
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
                : "Simulated write OK — \(note.text)."
        }
    }

    private func presentHTMLCard(payloadOrURL: String) {
        guard PasserbyHTMLCardView.extractPayload(payloadOrURL) != nil else {
            alertMessage = "Couldn't read a RedMed tap card from this tag."
            return
        }
        scannedHTMLPayload = payloadOrURL
        showScannedCard = true
    }
}
