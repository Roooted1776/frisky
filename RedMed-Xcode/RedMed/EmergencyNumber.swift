import Foundation

/// The local emergency number for the device's region.
///
/// The app used to hard-code `911`, which reaches nobody on a UK handset. Every
/// user-facing mention of the number and every `tel://` dial now goes through
/// here, so the UI and the dialler always agree with each other and with the
/// published Terms and Privacy Policy.
///
/// Region comes from `Locale.current.region` — the user's chosen region in
/// Settings, not the SIM and not the current GPS fix. That is the right source
/// for a resident travelling abroad, who is the common case; someone who has
/// moved permanently is expected to have changed their region setting.
///
/// The fallback is **112**, the GSM standard. Handsets route 112 to local
/// emergency services in most of the world, including the UK and the US, so an
/// unlisted region degrades to something that works rather than to nothing.
enum EmergencyNumber {

    /// Regions whose primary medical emergency number is not 112.
    ///
    /// Deliberately short. Every entry here is a number a wrong guess would make
    /// unreachable in an emergency, so the list stays limited to ones that are
    /// unambiguous, and everything else takes the 112 fallback.
    private static let byRegion: [String: String] = [
        "GB": "999",   // United Kingdom — 112 also routes
        "IE": "999",   // Ireland — 112 also routes
        "US": "911",
        "CA": "911",
        "MX": "911",
        "AU": "000",   // 112 routes from mobiles
        "NZ": "111",
        "JP": "119",   // fire and ambulance; 110 is police
        "IN": "112",
        "BR": "192",   // SAMU ambulance
        "AR": "107",
        "ZA": "10177"  // ambulance; 112 routes from mobiles
    ]

    /// GSM standard emergency number, routed to local services in most regions.
    static let fallback = "112"

    /// The number to dial and to show in copy, for this device's region.
    ///
    /// Resolved once per process, deliberately. Some callers are SwiftUI view
    /// bodies that re-evaluate on every render; others are the `let` catalogues
    /// in `AidTopicCatalog` and `aidPanes`, which Swift initialises lazily and
    /// exactly once. If this recomputed, changing the device region mid-session
    /// would update the first group and not the second, and a care step reading
    /// "Call 911" could sit directly above a button reading "Call 999".
    ///
    /// Two numbers on one screen is the worst possible failure for this app, so
    /// the whole process agrees on one value and a region change takes effect on
    /// next launch. Region is a Settings choice, not something that moves on its
    /// own, so that is a cheap price.
    static let current: String = {
        guard let region = Locale.current.region?.identifier else { return fallback }
        return byRegion[region] ?? fallback
    }()

    /// `tel://` URL for `current`, ready for `UIApplication.shared.open`.
    static var dialURL: URL? {
        URL(string: "tel://\(current)")
    }
}
