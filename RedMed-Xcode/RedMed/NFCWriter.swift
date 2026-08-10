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

    func writeURL(_ urlString: String) {
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

extension NFCWriter: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
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
                    session.invalidate(errorMessage: "This tag isn't NDEF-compatible. Use an NTAG213 or newer.")
                case .readOnly:
                    session.invalidate(errorMessage: "This tag is locked/read-only and can't be written.")
                case .readWrite:
                    guard let url = URL(string: urlString),
                          let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
                        session.invalidate(errorMessage: "Couldn't build the tag data.")
                        return
                    }
                    let message = NFCNDEFMessage(records: [payload])
                    tag.writeNDEF(message) { error in
                        if let error {
                            let capHint = capacity > 0 ? " Tag capacity: \(capacity) bytes." : ""
                            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription).\(capHint)")
                            return
                        }

                        tag.readNDEF { readMessage, readError in
                            if let readError {
                                session.alertMessage = "Written — couldn't verify read-back."
                                session.invalidate()
                                DispatchQueue.main.async {
                                    self?.success = true
                                    self?.verified = false
                                    self?.statusMessage = "Tag written. Verification skipped: \(readError.localizedDescription)"
                                    self?.isWriting = false
                                }
                                return
                            }

                            let written = readMessage?.records.first?.wellKnownTypeURIPayload()?.absoluteString
                            let ok = written == urlString
                            session.alertMessage = ok
                                ? "Success! Bracelet programmed and verified."
                                : "Written, but read-back didn't match. Test with another phone."
                            session.invalidate()
                            DispatchQueue.main.async {
                                self?.success = true
                                self?.verified = ok
                                self?.statusMessage = ok
                                    ? "Bracelet programmed and verified."
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
