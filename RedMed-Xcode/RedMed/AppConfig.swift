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
    ///   only from Write/Scan buttons. Product standoff: a hand at
    ///   `passiveNoTriggerInches` does not set the band off. Intentional
    ///   ISO 14443 coupling is still only ~cm to the phone antenna — HF NFC
    ///   cannot be programmed to a 16″ read range on an iPhone.
    enum BraceletRF {
        static let carrierMHz: Double = 13.56
        static let family = "ISO 14443 / NFC Forum Type 2 (NTAG213+)"
        static let isPassive = true
        static let usesBluetooth = false
        /// RedMed never starts NFC because a hand or band is merely nearby.
        static let requiresExplicitUserSession = true
        /// Casual / hand-nearby standoff — band must not “set off” at this distance.
        static let passiveNoTriggerInches = 16
        /// Typical ISO 14443 coupling for an intentional tap (physics, not a setting).
        static let typicalCouplingCentimeters = 4
    }
}
