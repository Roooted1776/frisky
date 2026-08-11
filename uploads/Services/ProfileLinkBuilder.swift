import Foundation

/// Builds the on-chip NDEF URI: profile JSON, base64url-encoded, after `#d=`.
/// New writes use `AppConfig.medicalCardBaseURL` (HTTPS hosted get/) so any
/// smartphone tap opens the emergency card in a browser. In-app decode also accepts `redmed://` and older
/// HTTPS `#d=` tags.
enum ProfileLinkBuilder {

    /// Match web `PROFILE_LIMITS.dEncodedMax` — reject hostile deep-link DoS before decode.
    private static let maxEncodedLength = 8192
    private static let maxName = 120
    private static let maxDob = 32
    private static let maxBlood = 16
    private static let maxUpdated = 40
    private static let maxListItem = 80
    private static let maxListCount = 32
    private static let maxContacts = 4
    private static let maxContactField = 160

    static func buildURL(profile: MedicalProfile, baseURL: String) -> URL? {
        var stamped = profile
        stamped.updated = ISO8601DateFormatter().string(from: Date())

        guard let jsonData = try? JSONEncoder().encode(stamped) else { return nil }
        let encoded = base64url(jsonData)
        return URL(string: baseURL + "#d=" + encoded)
    }

    /// Hosted card URL for the "preview in Safari" buttons — same encoding as `buildURL`,
    /// fixed to `AppConfig.medicalCardBaseURL` since previews always target the live host.
    static func previewURL(profile: MedicalProfile) -> URL? {
        buildURL(profile: profile, baseURL: AppConfig.medicalCardBaseURL)
    }

    /// On-screen guidance about which passive NFC tag size is needed.
    /// Counts the full NDEF URI (base URL + `#d=` + payload) — tag capacity is
    /// consumed by the whole string written to the chip, not just the profile.
    static func capacityNote(
        for profile: MedicalProfile,
        baseURL: String = AppConfig.medicalCardBaseURL
    ) -> (text: String, warn: Bool) {
        guard let jsonData = try? JSONEncoder().encode(profile) else {
            return ("", false)
        }
        let encoded = base64url(jsonData)
        let byteCount = (baseURL + "#d=" + encoded).utf8.count

        if byteCount > 850 {
            return ("\(byteCount) bytes on tag — too large for most NFC tags. Shorten your entries or use an NTAG216 (~888 bytes).", true)
        } else if byteCount > 480 {
            return ("\(byteCount) bytes on tag — needs an NTAG216.", false)
        } else if byteCount > 140 {
            return ("\(byteCount) bytes on tag — needs an NTAG215 or NTAG216.", false)
        } else {
            return ("\(byteCount) bytes on tag — fits any standard NFC tag (NTAG213+).", false)
        }
    }

    /// Reverse of buildURL — pulls the "#d=" fragment out of a URL string
    /// (whether it came from this device's own tag or the web app's) and
    /// decodes it straight into a profile. Pure string/JSON decoding, no
    /// network call: reading a tag never needs the hosted page to be
    /// reachable, only the bytes physically on the tag.
    static func decodeProfile(fromURLString urlString: String) -> MedicalProfile? {
        guard let range = urlString.range(of: "#d=") else { return nil }
        let encoded = String(urlString[range.upperBound...])
        guard encoded.utf8.count <= maxEncodedLength else { return nil }
        guard let data = base64urlDecode(encoded), data.count <= maxEncodedLength else { return nil }
        guard let profile = try? JSONDecoder().decode(MedicalProfile.self, from: data) else { return nil }
        return clamp(profile)
    }

    /// Cap hostile / oversized fields after Codable decode (mirrors web normalizeProfile).
    private static func clamp(_ profile: MedicalProfile) -> MedicalProfile {
        var p = profile
        p.name = String(p.name.prefix(maxName))
        p.dob = String(p.dob.prefix(maxDob))
        p.blood = String(p.blood.prefix(maxBlood))
        p.updated = String(p.updated.prefix(maxUpdated))
        p.allergies = Array(p.allergies.map { String($0.prefix(maxListItem)) }.prefix(maxListCount))
        p.meds = Array(p.meds.map { String($0.prefix(maxListItem)) }.prefix(maxListCount))
        p.conditions = Array(p.conditions.map { String($0.prefix(maxListItem)) }.prefix(maxListCount))
        p.contacts = Array(p.contacts.prefix(maxContacts).map { c in
            var contact = c
            contact.name = String(contact.name.prefix(maxContactField))
            contact.rel = String(contact.rel.prefix(maxContactField))
            contact.phone = String(contact.phone.prefix(32))
            return contact
        })
        return p
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64urlDecode(_ encoded: String) -> Data? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
