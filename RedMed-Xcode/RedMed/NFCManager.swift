import Foundation
import CoreNFC

/// Real CoreNFC session for writing / reading blank NDEF bracelets.
/// Write path: Face ID (caller) → encode CardPayload URI → NFCNDEFReaderSession write.
final class NFCManager: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    enum Mode {
        case write(NFCNDEFMessage)
        case read
    }

    @Published var isScanning = false
    @Published var lastError: String?
    @Published var lastWriteSucceeded = false
    @Published var lastReadURL: String?
    @Published var lastReadPayload: CardPayload?
    @Published var tagCapacityBytes: Int?
    @Published var lastPayloadBytes: Int?

    private var session: NFCNDEFReaderSession?
    private var mode: Mode?

    var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    func beginWrite(url: URL) {
        guard let record = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
            lastError = "Could not build NFC URI record."
            return
        }
        beginWrite(message: NFCNDEFMessage(records: [record]))
    }

    func beginWrite(message: NFCNDEFMessage) {
        guard isAvailable else {
            DispatchQueue.main.async {
                self.lastError = "NFC is not available on this device. Pairing requires a physical iPhone with NFC."
            }
            return
        }
        invalidateSession()
        mode = .write(message)
        lastError = nil
        lastWriteSucceeded = false
        lastPayloadBytes = message.length
        let s = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        s.alertMessage = "Hold the top of your iPhone near your blank RedMed bracelet."
        session = s
        DispatchQueue.main.async { self.isScanning = true }
        s.begin()
    }

    func beginRead() {
        guard isAvailable else {
            DispatchQueue.main.async {
                self.lastError = "NFC is not available on this device."
            }
            return
        }
        invalidateSession()
        mode = .read
        lastError = nil
        lastReadURL = nil
        lastReadPayload = nil
        let s = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        s.alertMessage = "Hold the top of your iPhone near your RedMed bracelet."
        session = s
        DispatchQueue.main.async { self.isScanning = true }
        s.begin()
    }

    func cancel() {
        session?.invalidate()
        invalidateSession()
    }

    private func invalidateSession() {
        session = nil
        mode = nil
        DispatchQueue.main.async { self.isScanning = false }
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let ns = error as NSError
        DispatchQueue.main.async {
            self.isScanning = false
            // User cancel / first-read complete — not an error to surface
            if ns.domain == NFCReaderError.errorDomain {
                let code = NFCReaderError.Code(rawValue: ns.code)
                if code == .readerSessionInvalidationErrorUserCanceled
                    || code == .readerSessionInvalidationErrorFirstNDEFTagRead {
                    return
                }
            }
            if !self.lastWriteSucceeded && self.lastReadPayload == nil {
                self.lastError = error.localizedDescription
            }
        }
        self.session = nil
        self.mode = nil
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Used when invalidateAfterFirstRead == true (read path without tag connection).
        guard case .read = mode else { return }
        handleRead(messages: messages, session: session)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }

        if tags.count > 1 {
            session.alertMessage = "More than one tag found. Please present a single bracelet."
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                session.restartPolling()
            }
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }

            tag.queryNDEFStatus { [weak self] status, capacity, error in
                guard let self else { return }
                if let error {
                    session.invalidate(errorMessage: error.localizedDescription)
                    return
                }

                DispatchQueue.main.async { self.tagCapacityBytes = capacity }

                switch self.mode {
                case .write(let message):
                    self.performWrite(tag: tag, message: message, status: status, capacity: capacity, session: session)
                case .read:
                    self.performRead(tag: tag, session: session)
                case .none:
                    session.invalidate()
                }
            }
        }
    }

    private func performWrite(
        tag: NFCNDEFTag,
        message: NFCNDEFMessage,
        status: NFCNDEFStatus,
        capacity: Int,
        session: NFCNDEFReaderSession
    ) {
        switch status {
        case .notSupported:
            session.invalidate(errorMessage: "This tag does not support NDEF.")
        case .readOnly:
            session.invalidate(errorMessage: "This bracelet is locked read-only and cannot be paired.")
        case .readWrite:
            if message.length > capacity {
                session.invalidate(errorMessage: "Profile is too large for this tag (\(message.length) B > \(capacity) B). Shorten medications or contacts.")
                return
            }
            tag.writeNDEF(message) { [weak self] error in
                guard let self else { return }
                if let error {
                    session.invalidate(errorMessage: error.localizedDescription)
                    return
                }
                DispatchQueue.main.async {
                    self.lastWriteSucceeded = true
                    self.tagCapacityBytes = capacity
                    self.lastPayloadBytes = message.length
                }
                session.alertMessage = "Bracelet paired. Your emergency card is on the band."
                session.invalidate()
            }
        @unknown default:
            session.invalidate(errorMessage: "Unknown tag status.")
        }
    }

    private func performRead(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { [weak self] message, error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }
            guard let message else {
                session.invalidate(errorMessage: "No NDEF message on this tag. Write your profile first.")
                return
            }
            self.handleRead(messages: [message], session: session)
            session.alertMessage = "Bracelet read."
            session.invalidate()
        }
    }

    private func handleRead(messages: [NFCNDEFMessage], session: NFCNDEFReaderSession) {
        for message in messages {
            for record in message.records {
                if let url = record.wellKnownTypeURIPayload() {
                    let urlString = url.absoluteString
                    let payload = CardPayload.decode(fromURLString: urlString)
                    DispatchQueue.main.async {
                        self.lastReadURL = urlString
                        self.lastReadPayload = payload
                        if payload == nil {
                            self.lastError = "Tag has a URL but no RedMed #d= profile payload."
                        }
                    }
                    return
                }
                // Fallback: text record containing the URL
                if let text = record.wellKnownTypeTextPayload().0 {
                    if let payload = CardPayload.decode(fromURLString: text) {
                        DispatchQueue.main.async {
                            self.lastReadURL = text
                            self.lastReadPayload = payload
                        }
                        return
                    }
                }
            }
        }
        DispatchQueue.main.async {
            self.lastError = "No RedMed card URL found on this tag."
        }
    }
}
