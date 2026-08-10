import Foundation

enum AppConfig {
    /// HTTPS shell written to passive NFC bands so any phone can open a browser.
    /// Medical data is only in the `#d=` fragment (no server storage). Source page:
    /// `RedMed-Xcode/RedMed/card.html` (bundled, unused in UI until a band is paired)
    /// and repo-root `card.html` (Pages).
    static let medicalCardBaseURL = "https://redmed.pages.dev/card/"

    /// Hardware RF contract for the RedMed bracelet.
    /// - Band is **passive**: no battery, no BLE/Wi‑Fi radio; the paired phone
    ///   only energises it during an intentional CoreNFC write/scan.
    /// - Band RF is **HF NFC at 13.56 MHz** (ISO 14443 / NTAG NDEF) — a different
    ///   carrier from phone Bluetooth (~2.4 GHz). Do not source LF (~125 kHz)
    ///   or UHF (~860–960 MHz) chips; iPhone CoreNFC cannot program those.
    /// - Contactless payment POS also uses 13.56 MHz but speaks EMV, not NDEF
    ///   medical URLs — protocol separation, not a second MHz.
    /// - No proximity / “hand close” trigger in RedMed: CoreNFC sessions start
    ///   only from Write/Scan buttons. Product standoff: a hand or another
    ///   device at `passiveNoTriggerInches` does not set the band off. POS /
    ///   pay terminals ignore NDEF medical URLs (EMV). Intentional ISO 14443
    ///   coupling is still only ~cm to a phone antenna — HF NFC cannot be
    ///   programmed to a 16″ read range, and a deliberate stranger tap must
    ///   still open the emergency card.
    enum BraceletRF {
        static let carrierMHz: Double = 13.56
        static let family = "ISO 14443 / NFC Forum Type 2 (NTAG213+)"
        static let isPassive = true
        static let usesBluetooth = false
        /// RedMed never starts NFC because a hand or band is merely nearby.
        static let requiresExplicitUserSession = true
        /// Casual standoff — band must not “set off” owner phone, other phones,
        /// or pay/POS readers at this distance (walk-by / hand nearby).
        static let passiveNoTriggerInches = 16
        /// Typical ISO 14443 coupling for an intentional tap (physics, not a setting).
        static let typicalCouplingCentimeters = 4
        /// Payment terminals speak EMV; they do not open RedMed NDEF URLs.
        static let ignoredByPaymentPOS = true
    }
}
