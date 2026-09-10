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
    /// Scan / simulate → full passerby shell (item present; payload never empty).
    /// NFC UI uses Preview for the helper card; this path remains for hardware verifyBand.
    @Published var scannedCard: ScannedCardSession?
    @Published var alertMessage: String?

    /// One-shot Scan open — same shape as NFCView.PreviewSession.
    struct ScannedCardSession: Identifiable {
        let id = UUID()
        let payload: String
        let embedJSON: String?
    }

    /// CoreNFC sessions stay cold until first write/read — YOU-card open
    /// must not pay for NFCWriter / NFCReader construction.
    private var writerStorage: NFCWriter?
    private var readerStorage: NFCReader?
    private var didBindSessions = false
    private var cancellables = Set<AnyCancellable>()
    var isBusy: Bool { isWriting || isReading }

    private var writer: NFCWriter {
        ensureSessions()
        return writerStorage!
    }

    private var reader: NFCReader {
        ensureSessions()
        return readerStorage!
    }

    init() {}

    private func ensureSessions() {
        if writerStorage == nil { writerStorage = NFCWriter() }
        if readerStorage == nil { readerStorage = NFCReader() }
        guard !didBindSessions else { return }
        didBindSessions = true
        bindSessions()
    }

    // MARK: - Write (owner band setup)

    /// Snapshot live RedMed → AES-GCM `#d=` → CoreNFC write (or pack-only when parked).
    /// Pack + `session.begin()` stay on this tap's stack (NFC tab open / Write).
    /// Once the sheet is up, hold the band ~1–2″ to finish. CoreNFC drops the
    /// sheet if Write hops through `Task` / `Task.detached` first.
    /// Parked Share Band URL on the NFC tab is the same `OwnerBandURI` string.
    /// No Face ID here — post-Agree / Edit / Save / Erase / Load From Band only
    /// (not viewing the YOU card).
    /// Linked / Not linked flips only after a real verified CoreNFC write, or
    /// owner Load From Band that persist()s the chip — never simulate or share.
    func writeBand(from profile: ProfileData, isScannerSession: Bool) {
        guard !isScannerSession else { return }
        guard !isBusy else { return }
        guard profile.hasSensitiveProfileData else { return }

        let chip = ProfileNFCCodec.chipProfile(from: profile)
        guard let urlString = ProfileNFCCodec.buildURLString(chip: chip),
              AppConfig.OwnerBandURI.isValidWriteURL(urlString) else {
            alertMessage = "Couldn't build a RedMed #d= tag payload (vendor/social URLs are blocked)."
            return
        }
        lastPackedURL = urlString
        if urlString.utf8.count > 850 {
            alertMessage = "\(urlString.utf8.count) bytes — too large for NXP NTAG216. Shorten RedMed."
            return
        }
        if AppConfig.nfcHardwareEnabled {
            statusMessage = ""
            writeSucceeded = false
            writeVerified = false
            writer.writeURL(urlString)
        } else {
            // Parked: pack only — never a Write, never Linked.
            lastPackedURL = urlString
            writeSucceeded = false
            writeVerified = false
            isWriting = false
            statusMessage = ""
        }
    }

    /// Drop a live write/read sheet when leaving the NFC tab.
    func cancelSessions() {
        guard didBindSessions else { return }
        writer.cancel()
        reader.cancel()
    }

    /// Owner Load From Band: CoreNFC read on this tap, then caller Face IDs and persist()s.
    /// Does not open the helper card. Scanners never. Parked builds have no session.
    func readBandForLoad(
        isScannerSession: Bool,
        onChip: @escaping (NFCChipProfile) -> Void
    ) {
        guard !isScannerSession else { return }
        guard !isBusy else { return }
        guard AppConfig.nfcHardwareEnabled else {
            alertMessage = "NFC reading is disabled in this build."
            return
        }
        statusMessage = ""
        reader.readTag(alertMessage: "Hold your iPhone near the bracelet to load the card.") { [weak self] chip, _ in
            self?.statusMessage = ""
            onChip(chip)
        }
    }

    // MARK: - Verify / scan (same HTML shell a stranger gets on band tap)

    /// Hardware path: CoreNFC → strip NDEF → open bundled tap card (?src=app, no SOS arm).
    /// Simulate path: pack live RedMed → same one-page HTML cover (tap card).
    /// Hardware sessions gated by `AppConfig.nfcHardwareEnabled`.
    func verifyBand(from profile: ProfileData) {
        guard !isBusy else { return }
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
        Task { @MainActor [weak self] in
            let packed = await Task.detached(priority: .userInitiated) {
                (
                    ProfileNFCCodec.buildURLString(chip: chip),
                    ProfileNFCCodec.embedProfileJSON(from: chip)
                )
            }.value
            guard let self else { return }
            self.isReading = false
            self.statusMessage = ""
            guard let url = packed.0 else {
                self.alertMessage = "Couldn't pack or decode the tap card from RedMed."
                return
            }
            self.presentHTMLCard(payloadOrURL: url, embedJSON: packed.1)
        }
    }

    func dismissScannedCard() {
        scannedCard = nil
    }

    /// Universal Link / notification path: open the hosted `#d=` as an in-app
    /// tap card (`?src=app`, no SOS). Does not touch owner Keychain.
    func presentBandURLFromUniversalLink(_ urlString: String) {
        presentHTMLCard(payloadOrURL: urlString)
    }

    /// Mark owner bracelet paired after a real CoreNFC write **and** matching read-back.
    func linkBracelet(on profile: ProfileData, detail: String) {
        guard AppConfig.nfcHardwareEnabled, writeVerified else { return }
        guard profile.setBraceletPaired(true) else {
            alertMessage = "Bracelet write succeeded, but RedMed couldn't save the paired status. Try again."
            return
        }
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

    private func presentHTMLCard(payloadOrURL: String, embedJSON: String? = nil) {
        guard PasserbyHTMLCardView.extractPayload(payloadOrURL) != nil else {
            alertMessage = "Couldn't read a RedMed tap card from this tag."
            return
        }
        scannedCard = ScannedCardSession(payload: payloadOrURL, embedJSON: embedJSON)
    }
}
