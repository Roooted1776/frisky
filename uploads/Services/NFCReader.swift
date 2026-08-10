import CoreNFC

/// Reads a tag written by this app back into a MedicalProfile — entirely
/// on-device. The NDEF payload is a URI whose `#d=` fragment holds the
/// profile as base64url (HTTPS for new writes; `redmed://` legacy OK).
/// ProfileLinkBuilder.decodeProfile is local — only physical proximity needed.
final class NFCReader: NSObject, ObservableObject {
    @Published var statusMessage: String = ""
    @Published var isReading = false

    private var session: NFCNDEFReaderSession?
    private var onProfile: ((MedicalProfile, String) -> Void)?
    private var didDeliver = false

    /// - Parameter alertMessage: System NFC sheet prompt. Use a first-responder
    ///   wording when scanning a stranger's band (not importing onto My ID).
    func readTag(
        alertMessage: String = "Hold your iPhone near the tag to read your medical ID.",
        onProfile: @escaping (MedicalProfile, String) -> Void
    ) {
        guard NFCNDEFReaderSession.readingAvailable else {
            statusMessage = "This device doesn't support NFC tag reading."
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

    private func deliverProfile(from urlString: String, session: NFCNDEFReaderSession) {
        guard !didDeliver else { return }
        guard let profile = ProfileLinkBuilder.decodeProfile(fromURLString: urlString) else {
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
              let urlString = payload.wellKnownTypeURIPayload()?.absoluteString else {
            session.invalidate(errorMessage: "Couldn't read a RedMed card from this tag.")
            DispatchQueue.main.async { [weak self] in
                self?.isReading = false
                self?.statusMessage = "Couldn't read a RedMed card from this tag."
            }
            return
        }
        deliverProfile(from: urlString, session: session)
    }

    /// Newer iPhones and NTAG chips often surface tags here instead of didDetectNDEFs.
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
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

                guard let urlString = message?.records.first?.wellKnownTypeURIPayload()?.absoluteString else {
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
