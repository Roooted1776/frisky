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

    /// Starts a CoreNFC session only from an explicit Write tap — never on proximity.
    /// No Simulator fake-success path — failures stay failures.
    /// Accepts only `medicalCardBaseURL#d=…` — never vendor clouds, social/short
    /// links, App Store URLs, or any non-`#d=` NDEF.
    func writeURL(_ urlString: String) {
        guard AppConfig.OwnerBandURI.isValidWriteURL(urlString) else {
            DispatchQueue.main.async {
                self.statusMessage = "Band write refused — only RedMed #d= URLs are allowed (no vendor cloud, social, or short links)."
                self.success = false
                self.isWriting = false
            }
            return
        }
        guard AppConfig.nfcHardwareEnabled else {
            DispatchQueue.main.async {
                self.statusMessage = "NFC writing is disabled in this build."
                self.success = false
                self.isWriting = false
            }
            return
        }
        guard NFCNDEFReaderSession.readingAvailable else {
            DispatchQueue.main.async {
                self.statusMessage = "NFC writing needs a physical iPhone with NFC Tag Reading enabled."
                self.success = false
                self.isWriting = false
            }
            return
        }
        urlToWrite = urlString
        success = false
        verified = false
        isWriting = true
        statusMessage = "Hold your iPhone near the NFC tag."

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
                        errorMessage: "Not a passive 13.56 MHz Type 2 NDEF tag. Use a blank rewritable NTAG213+ HF bracelet chip."
                    )
                case .readOnly:
                    session.invalidate(
                        errorMessage: "This tag is locked/read-only. RedMed needs a rewritable Type 2 (NTAG) band — not factory-locked."
                    )
                case .readWrite:
                    guard let payload = NFCURICodec.payload(for: urlString) else {
                        session.invalidate(errorMessage: "Couldn't build the tag data.")
                        return
                    }
                    let message = NFCNDEFMessage(records: [payload])
                    if capacity > 0, message.length > capacity {
                        session.invalidate(
                            errorMessage: "Profile is \(message.length) bytes; this Type 2 tag only holds \(capacity). Shorten RedMed or use NTAG216."
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
                                session.invalidate()
                                DispatchQueue.main.async {
                                    self?.success = true
                                    self?.verified = false
                                    self?.statusMessage = "Tag written. Verification skipped: \(readError.localizedDescription)"
                                    self?.isWriting = false
                                }
                                return
                            }

                            let written = readMessage?.records.first.flatMap { NFCURICodec.string(from: $0) }
                            let ok = written.map { NFCURICodec.match($0, urlString) } ?? false
                            session.alertMessage = ok
                                ? "Success! Bracelet programmed and verified."
                                : "Written, but read-back didn't match. Test with another phone."
                            session.invalidate()
                            DispatchQueue.main.async {
                                self?.success = true
                                self?.verified = ok
                                self?.statusMessage = ok
                                    ? "Bracelet programmed and verified. Other phones can tap it; payment terminals cannot."
                                    : "Written, but verification failed — try writing again."
                                self?.isWriting = false
                            }
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unrecognized tag status.")
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
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
