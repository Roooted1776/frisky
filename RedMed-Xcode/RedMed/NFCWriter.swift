import CoreNFC
import Foundation

/// CoreNFC write + read-back. Delegate callbacks are not main-thread; hop @Published.
final class NFCWriter: NSObject, ObservableObject {
    @Published var statusMessage: String = ""
    @Published var isWriting = false
    @Published var success = false
    @Published var verified = false

    private var session: NFCNDEFReaderSession?
    private var urlToWrite: String = ""

    /// Opens the system write sheet from an NFC-tab / Write user action.
    /// Proximity does the write once the sheet is up — hold the band ~1–2″.
    /// Must run on the same main-thread stack as that action. Do not wrap
    /// the caller in `Task` first — iOS then refuses / silently drops the sheet.
    /// No Simulator fake-success path — failures stay failures.
    /// Accepts only `medicalCardBaseURL#d=…` — never vendor clouds, social/short
    /// links, App Store URLs, or any non-`#d=` NDEF.
    func writeURL(_ urlString: String) {
        guard AppConfig.OwnerBandURI.isValidWriteURL(urlString) else {
            statusMessage = "Band write refused — only RedMed #d= URLs are allowed (no vendor cloud, social, or short links)."
            success = false
            isWriting = false
            return
        }
        guard AppConfig.nfcHardwareEnabled else {
            statusMessage = "NFC writing is disabled in this build."
            success = false
            isWriting = false
            return
        }
        guard NFCNDEFReaderSession.readingAvailable else {
            statusMessage = "NFC writing needs a physical iPhone with NFC Tag Reading enabled."
            success = false
            isWriting = false
            return
        }
        urlToWrite = urlString
        success = false
        verified = false
        isWriting = true
        statusMessage = "Hold your iPhone near the NFC tag."

        // Do not invalidate-then-begin. A live session is still tearing down
        // after the last write; starting the next one waits until `didInvalidate`
        // nils `session` and `isWriting` (Write stays disabled until then).
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "Hold your iPhone near the NFC tag to write your RedMed card."
        self.session = session
        session.begin()
    }

    func cancel() {
        session?.invalidate()
        session = nil
        DispatchQueue.main.async {
            self.isWriting = false
        }
    }

}

/// NDEF URI helpers — keep `#d=` fragments intact for iOS Background Tag Reading.
/// Hand-build TNF Well Known type "U" so Safari gets `https://…/tapper/#d=…`
/// even when the screen is off or locked (iPhone XS+). Apple's URI helper can
/// drop the fragment, which opens bare `/tapper/` instead of the card.
enum NFCURICodec {
    static func payload(for urlString: String) -> NFCNDEFPayload? {
        if let payload = wellKnownURIRecord(urlString) {
            return payload
        }
        if let payload = NFCNDEFPayload.wellKnownTypeURIPayload(string: urlString) {
            return payload
        }
        guard let url = URL(string: urlString) else { return nil }
        return NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
    }

    /// NFC Forum URI Record (RTD-URI): identifier code + UTF-8 remainder.
    /// `0x04` = `https://` so BTR treats this as a website, not a custom scheme.
    static func wellKnownURIRecord(_ urlString: String) -> NFCNDEFPayload? {
        let prefixes: [(UInt8, String)] = [
            (0x02, "https://www."),
            (0x01, "http://www."),
            (0x04, "https://"),
            (0x03, "http://")
        ]
        var identifier: UInt8 = 0x00
        var remainder = urlString
        for (code, prefix) in prefixes {
            if urlString.count >= prefix.count,
               urlString.lowercased().hasPrefix(prefix) {
                identifier = code
                remainder = String(urlString.dropFirst(prefix.count))
                break
            }
        }
        guard let rest = remainder.data(using: .utf8) else { return nil }
        var bytes = Data([identifier])
        bytes.append(rest)
        return NFCNDEFPayload(
            format: .nfcWellKnown,
            type: Data("U".utf8),
            identifier: Data(),
            payload: bytes
        )
    }

    static func string(from payload: NFCNDEFPayload) -> String? {
        // Decode the raw RTD-URI first so `#d=` survives read-back / BTR.
        if payload.typeNameFormat == .nfcWellKnown,
           let type = String(data: payload.type, encoding: .utf8), type == "U",
           !payload.payload.isEmpty {
            let code = payload.payload[payload.payload.startIndex]
            let rest = payload.payload.dropFirst()
            if let body = String(data: Data(rest), encoding: .utf8) {
                let prefixes: [UInt8: String] = [
                    0x00: "",
                    0x01: "http://www.",
                    0x02: "https://www.",
                    0x03: "http://",
                    0x04: "https://"
                ]
                return (prefixes[code] ?? "") + body
            }
        }
        if let url = payload.wellKnownTypeURIPayload() {
            return url.absoluteString
        }
        return nil
    }

    static func match(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard let ua = URL(string: a), let ub = URL(string: b) else { return false }
        return ua.scheme?.lowercased() == ub.scheme?.lowercased()
            && ua.host?.lowercased() == ub.host?.lowercased()
            && ua.path == ub.path
            && ua.fragment == ub.fragment
    }
}

extension NFCWriter: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

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

        let urlString = urlToWrite
        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                if let error {
                    session.invalidate(errorMessage: "Failed to read tag: \(error.localizedDescription)")
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(
                        errorMessage: "Not a blank unlocked NXP NTAG216 (13.56 MHz, ISO 14443A Type 2). Not NTAG213, MIFARE, LF, or UHF."
                    )
                case .readOnly:
                    session.invalidate(
                        errorMessage: "This tag is locked/read-only. RedMed needs NDEF blank unlocked — no factory lock."
                    )
                case .readWrite:
                    guard let payload = NFCURICodec.payload(for: urlString) else {
                        session.invalidate(errorMessage: "Couldn't build the tag data.")
                        return
                    }
                    let message = NFCNDEFMessage(records: [payload])
                    if capacity > 0, message.length > capacity {
                        session.invalidate(
                            errorMessage: "Profile is \(message.length) bytes; this tag only holds \(capacity). Shorten RedMed. Product band is NXP NTAG216."
                        )
                        return
                    }
                    tag.writeNDEF(message) { error in
                        if let error {
                            let capHint = capacity > 0 ? " Tag capacity: \(capacity) bytes." : ""
                            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription).\(capHint)")
                            return
                        }

                        tag.readNDEF { readMessage, readError in
                            if let readError {
                                session.alertMessage = "Written — couldn't verify read-back. Test with another phone."
                                self?.finishWrite(
                                    success: true,
                                    verified: false,
                                    status: "Tag written. Verification skipped: \(readError.localizedDescription)",
                                    thenInvalidate: session
                                )
                                return
                            }

                            let written = readMessage?.records.first.flatMap { NFCURICodec.string(from: $0) }
                            let ok = written.map { NFCURICodec.match($0, urlString) } ?? false
                            session.alertMessage = ok
                                ? "Success! Bracelet programmed and verified."
                                : "Written, but read-back didn't match. Test with another phone."
                            self?.finishWrite(
                                success: true,
                                verified: ok,
                                status: ok
                                    ? "Bracelet programmed and verified. Other phones can tap it; payment terminals cannot."
                                    : "Written, but verification failed — try writing again.",
                                thenInvalidate: session
                            )
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unrecognized tag status.")
                }
            }
        }
    }

    /// Mark outcome on main *before* invalidate so `didInvalidate` cannot
    /// overwrite a successful write with the session-end error.
    private func finishWrite(
        success: Bool,
        verified: Bool,
        status: String,
        thenInvalidate session: NFCNDEFReaderSession
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.success = success
            self.verified = verified
            self.statusMessage = status
            self.isWriting = false
            session.invalidate()
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.session === session {
                self.session = nil
            }
            self.isWriting = false
            if let readerError = error as? NFCReaderError,
               readerError.code == .readerSessionInvalidationErrorUserCanceled {
                self.statusMessage = "Cancelled."
            } else if !self.success {
                self.statusMessage = error.localizedDescription
            }
        }
    }
}
