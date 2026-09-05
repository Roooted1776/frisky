import CoreNFC
import Foundation

/// Reads a RedMed `#d=` NDEF URI from a bracelet. No network — chip bytes only.
/// Session half of `NFCBandManager`: CoreNFC → `NFCURICodec` strip →
/// `ProfileNFCCodec` CryptoKit decrypt.
final class NFCReader: NSObject, ObservableObject {
    @Published var statusMessage: String = ""
    @Published var isReading = false

    private var session: NFCNDEFReaderSession?
    private var onProfile: ((NFCChipProfile, String) -> Void)?
    private var didDeliver = false

    /// Opens the system read sheet from an explicit Scan tap.
    /// Hold completes the read once the sheet is up.
    /// No Simulator fake-success path — failures stay failures.
    func readTag(
        alertMessage: String = "Hold your iPhone near the tag to read the RedMed card.",
        onProfile: @escaping (NFCChipProfile, String) -> Void
    ) {
        guard AppConfig.nfcHardwareEnabled else {
            DispatchQueue.main.async {
                self.statusMessage = "NFC reading is disabled in this build."
                self.isReading = false
            }
            return
        }
        guard NFCNDEFReaderSession.readingAvailable else {
            DispatchQueue.main.async {
                self.statusMessage = "NFC reading needs a physical iPhone with NFC Tag Reading enabled."
                self.isReading = false
            }
            return
        }
        self.onProfile = onProfile
        didDeliver = false
        isReading = true
        statusMessage = "Hold your iPhone near the NFC tag."

        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session.alertMessage = alertMessage
        self.session = session
        session.begin()
    }

    func cancel() {
        session?.invalidate()
        session = nil
        DispatchQueue.main.async {
            self.isReading = false
        }
    }

    private func deliverProfile(from urlString: String, session: NFCNDEFReaderSession) {
        guard !didDeliver else { return }
        guard let profile = ProfileNFCCodec.decodeProfile(fromURLString: urlString) else {
            session.invalidate(errorMessage: "Couldn't read a RedMed card from this tag.")
            DispatchQueue.main.async { [weak self] in
                self?.isReading = false
                self?.statusMessage = "Couldn't read a RedMed card from this tag."
            }
            return
        }

        didDeliver = true
        session.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.isReading = false
            self?.statusMessage = ""
            self?.onProfile?(profile, urlString)
        }
    }
}

extension NFCReader: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let payloads = messages.flatMap(\.records)
        guard let payload = payloads.first,
              let urlString = NFCURICodec.string(from: payload) else {
            session.invalidate(errorMessage: "Couldn't read a RedMed card from this tag.")
            DispatchQueue.main.async { [weak self] in
                self?.isReading = false
                self?.statusMessage = "Couldn't read a RedMed card from this tag."
            }
            return
        }
        deliverProfile(from: urlString, session: session)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "More than one tag found. Hold only the bracelet."
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
                session.restartPolling()
            }
            return
        }

        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found. Try again.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }

            tag.readNDEF { message, error in
                if let error {
                    session.invalidate(errorMessage: "Read failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.isReading = false
                        self?.statusMessage = error.localizedDescription
                    }
                    return
                }

                guard let urlString = message?.records.first.flatMap({ NFCURICodec.string(from: $0) }) else {
                    session.invalidate(errorMessage: "Couldn't read a RedMed card from this tag.")
                    DispatchQueue.main.async {
                        self?.isReading = false
                        self?.statusMessage = "Couldn't read a RedMed card from this tag."
                    }
                    return
                }

                self?.deliverProfile(from: urlString, session: session)
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReading = false
            if let readerError = error as? NFCReaderError,
               readerError.code == .readerSessionInvalidationErrorUserCanceled {
                self.statusMessage = "Cancelled."
            }
        }
    }
}
