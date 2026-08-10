import Foundation
import CoreNFC

/// Real CoreNFC session for writing / reading blank NDEF bracelets.
/// Owned at the app root so tab switches cannot discard an in-flight session.
///
/// On Simulator (and any host where CoreNFC is unavailable), write/read run in a
/// device-like demo path so the NFC tab can be walked through without hardware.
final class NFCManager: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    enum Mode {
        case write(NFCNDEFMessage)
        case read
    }

    enum ReadIntent: Equatable {
        case none
        case scanPreview
        case importToPhone
    }

    /// Typical user-memory size for NTAG216 — used for demo capacity reporting.
    private static let demoTagCapacityBytes = 888

    @Published var isScanning = false
    @Published var lastError: String?
    @Published var lastWriteSucceeded = false
    @Published var lastReadURL: String?
    @Published var lastReadPayload: CardPayload?
    @Published var tagCapacityBytes: Int?
    @Published var lastPayloadBytes: Int?
    /// Intent captured when the read session starts — not mutable from the UI mid-scan.
    @Published private(set) var readIntent: ReadIntent = .none
    /// True while the Simulator/demo hold-to-band overlay should be shown.
    @Published private(set) var isDemoSession = false

    private var session: NFCNDEFReaderSession?
    private var mode: Mode?
    private var demoWorkItem: DispatchWorkItem?
    /// Last URL written in demo mode — reused for scan/import when no hardware tag exists.
    private var demoStoredURL: String?

    /// Hardware CoreNFC present (false on Simulator).
    var isHardwareAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    /// UI treats NFC as available even on Simulator so the pairing flow is walkable.
    var isAvailable: Bool { true }

    func beginWrite(url: URL) {
        guard let record = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
            lastError = "Could not build NFC URI record."
            return
        }
        beginWrite(message: NFCNDEFMessage(records: [record]), demoURLString: url.absoluteString)
    }

    func beginWrite(message: NFCNDEFMessage, demoURLString: String? = nil) {
        guard !isScanning else {
            DispatchQueue.main.async {
                self.lastError = "NFC session already in progress. Finish or cancel it first."
            }
            return
        }

        if !isHardwareAvailable {
            beginDemoWrite(message: message, urlString: demoURLString)
            return
        }

        invalidateSession()
        mode = .write(message)
        readIntent = .none
        lastError = nil
        lastWriteSucceeded = false
        lastPayloadBytes = message.length
        isDemoSession = false
        let s = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        s.alertMessage = "Hold the top of your iPhone near your blank RedMed bracelet."
        session = s
        DispatchQueue.main.async { self.isScanning = true }
        s.begin()
    }

    /// Starts a read session for a single intent. Concurrent reads are rejected so intent cannot be overwritten mid-scan.
    @discardableResult
    func beginRead(for intent: ReadIntent) -> Bool {
        guard intent == .scanPreview || intent == .importToPhone else { return false }
        guard !isScanning else {
            DispatchQueue.main.async {
                self.lastError = "NFC session already in progress. Finish or cancel it first."
            }
            return false
        }

        if !isHardwareAvailable {
            return beginDemoRead(for: intent)
        }

        invalidateSession()
        mode = .read
        readIntent = intent
        lastError = nil
        lastReadURL = nil
        lastReadPayload = nil
        isDemoSession = false
        let s = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        s.alertMessage = "Hold the top of your iPhone near your RedMed bracelet."
        session = s
        DispatchQueue.main.async { self.isScanning = true }
        s.begin()
        return true
    }

    func cancel() {
        demoWorkItem?.cancel()
        demoWorkItem = nil
        session?.invalidate()
        invalidateSession()
        DispatchQueue.main.async {
            self.isDemoSession = false
            self.readIntent = .none
        }
    }

    /// Call after the UI has consumed `lastReadPayload` for the active intent.
    func consumeReadResult() {
        readIntent = .none
        lastReadPayload = nil
        lastReadURL = nil
    }

    private func invalidateSession() {
        demoWorkItem?.cancel()
        demoWorkItem = nil
        session = nil
        mode = nil
        DispatchQueue.main.async {
            self.isScanning = false
            self.isDemoSession = false
        }
    }

    // MARK: - Simulator / no-hardware demo

    private func beginDemoWrite(message: NFCNDEFMessage, urlString: String?) {
        invalidateSession()
        mode = .write(message)
        readIntent = .none
        lastError = nil
        lastWriteSucceeded = false
        lastPayloadBytes = message.length
        let payloadBytes = message.length
        let storedURL = urlString

        DispatchQueue.main.async {
            self.isDemoSession = true
            self.isScanning = true
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.demoStoredURL = storedURL
            DispatchQueue.main.async {
                self.lastWriteSucceeded = true
                self.tagCapacityBytes = Self.demoTagCapacityBytes
                self.lastPayloadBytes = payloadBytes
                self.isScanning = false
                self.isDemoSession = false
                self.mode = nil
            }
        }
        demoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    @discardableResult
    private func beginDemoRead(for intent: ReadIntent) -> Bool {
        invalidateSession()
        mode = .read
        readIntent = intent
        lastError = nil
        lastReadURL = nil
        lastReadPayload = nil

        DispatchQueue.main.async {
            self.isDemoSession = true
            self.isScanning = true
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard let urlString = self.demoStoredURL,
                  let payload = CardPayload.decode(fromURLString: urlString) else {
                DispatchQueue.main.async {
                    self.lastError = "No NDEF message on this tag. Write your profile first."
                    self.readIntent = .none
                    self.isScanning = false
                    self.isDemoSession = false
                    self.mode = nil
                }
                return
            }
            DispatchQueue.main.async {
                self.lastReadURL = urlString
                self.lastReadPayload = payload
                self.tagCapacityBytes = Self.demoTagCapacityBytes
                self.isScanning = false
                self.isDemoSession = false
                self.mode = nil
            }
        }
        demoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
        return true
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
                if code == .readerSessionInvalidationErrorUserCanceled {
                    self.readIntent = .none
                    return
                }
                if code == .readerSessionInvalidationErrorFirstNDEFTagRead {
                    return
                }
            }
            if !self.lastWriteSucceeded && self.lastReadPayload == nil {
                self.lastError = error.localizedDescription
                self.readIntent = .none
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
                            self.readIntent = .none
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
            self.readIntent = .none
        }
    }
}
