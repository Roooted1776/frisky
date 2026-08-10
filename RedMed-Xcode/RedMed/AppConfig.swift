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
    enum BraceletRF {
        static let carrierMHz: Double = 13.56
        static let family = "ISO 14443 / NFC Forum Type 2 (NTAG213+)"
        static let isPassive = true
        static let usesBluetooth = false
    }
}
