import Foundation

/// Compact emergency-card payload encoded into the NFC NDEF URI `#d=` fragment.
/// Roadside first-aid content is NOT stored on the tag — it lives on the static card page.
struct CardPayload: Codable, Equatable {
    var n: String
    var b: String
    var bt: String
    var a: [String]
    var m: [String]
    var c: [String]
    var e: [Contact]
    var o: Bool?
    var u: String?

    struct Contact: Codable, Equatable {
        var n: String
        var d: String
    }

    /// Hosted static card (Cloudflare Pages). Fragment never leaves the browser.
    static let cardBaseURL = "https://redmed.pages.dev/card"

    static func from(profile: ProfileData) -> CardPayload {
        CardPayload(
            n: profile.name,
            b: profile.birthDate,
            bt: profile.bloodType,
            a: profile.allergies,
            m: profile.medications,
            c: profile.conditions,
            e: profile.contacts.map { Contact(n: $0.name, d: $0.detail) },
            o: profile.isOrganDonor,
            u: profile.lastUpdated
        )
    }

    func apply(to profile: ProfileData, persist: Bool = true) {
        profile.name = n
        profile.birthDate = b
        profile.bloodType = bt
        profile.allergies = a
        profile.medications = m
        profile.conditions = c
        profile.contacts = e.map { EmergencyContact(name: $0.n, detail: $0.d) }
        if let o { profile.isOrganDonor = o }
        if let u { profile.lastUpdated = u }
        if persist {
            profile.braceletLinked = true
            profile.persist()
        }
    }

    func encodedFragment() throws -> String {
        let data = try JSONEncoder().encode(self)
        return data.base64URLEncodedString()
    }

    func cardURL() throws -> URL {
        let fragment = try encodedFragment()
        guard let url = URL(string: "\(Self.cardBaseURL)#d=\(fragment)") else {
            throw CardPayloadError.invalidURL
        }
        return url
    }

    /// Estimated NDEF URI record size in bytes (URI identifier + payload).
    func estimatedNDEFByteCount() throws -> Int {
        let url = try cardURL()
        // NFC Forum URI record: 1-byte identifier code + UTF-8 remainder after "https://"
        let absolute = url.absoluteString
        let remainder: String
        if absolute.hasPrefix("https://") {
            remainder = String(absolute.dropFirst("https://".count))
        } else {
            remainder = absolute
        }
        return 1 + remainder.utf8.count
    }

    static func decode(fromURLString urlString: String) -> CardPayload? {
        guard let hashRange = urlString.range(of: "#d=") else { return nil }
        let encoded = String(urlString[hashRange.upperBound...])
            .split(separator: "&").first
            .map(String.init) ?? ""
        guard let data = Data(base64URLEncoded: encoded) else { return nil }
        return try? JSONDecoder().decode(CardPayload.self, from: data)
    }
}

enum CardPayloadError: Error {
    case invalidURL
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - s.count % 4) % 4
        if pad > 0 { s.append(String(repeating: "=", count: pad)) }
        self.init(base64Encoded: s)
    }
}
