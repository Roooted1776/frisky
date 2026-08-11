import Foundation

enum AppConfig {
    /// Update when the App Store listing is live (App Store Connect app ID).
    /// Packaging QR / setup links point here — not at an HTML landing page.
    static let appStoreURL = "https://apps.apple.com/app/redmed/id0000000000"

    /// Alias for setup QR / deep links (same as `appStoreURL`).
    static let getStartedURL = appStoreURL

    /// HTTPS URI written to passive NFC bands (CoreNFC). `#d=…` on chip.
    /// Tap the band → any smartphone opens the hosted emergency card in the browser.
    /// No app for readers. In-app NFC scan and `redmed://card` decode to `ScannedCardView`.
    static let medicalCardBaseURL = "https://redmed.pages.dev/get"

    /// Older bands may carry `/card/` or `redmed://card`; in-app decode still accepts `#d=`.
    static let legacyHostedCardBaseURL = "https://redmed.pages.dev/card/"

    static let privacyPolicyURL = "https://redmed.pages.dev/privacy-policy.html"

    /// Device-direct third-party emergency alert (RapidSOS / Noonlight / HTTPS webhook).
    /// Empty = disabled (no network). RedMed does not operate a relay server.
    /// Set at build time for a partner endpoint; never commit a live secret.
    static let thirdPartyEmergencyAlertURL = ""

    /// Optional Bearer token for `thirdPartyEmergencyAlertURL`. Empty when unused.
    static let thirdPartyEmergencyAlertToken = ""
}
