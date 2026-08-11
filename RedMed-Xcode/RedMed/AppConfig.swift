import Foundation

enum AppConfig {
    /// Passerby / rescuer shell written to passive NFC bands. Any phone that taps
    /// the bracelet opens this page in a browser — read-only medical card + Help +
    /// Aid. Medical data is only in the `#d=` fragment (no server storage). Owner
    /// edit / treatments live in `Main.swift`, not here. Source page:
    /// `RedMed-Xcode/RedMed/card.html` (bundled) and repo-root `card.html` (Pages).
    static let medicalCardBaseURL = "https://redmed.pages.dev/card/"

    /// Deep link target for policy / card HTML “open owner app” redirects.
    static let mainAppURL = "redmed://main"

    /// Update when the App Store listing is live (App Store Connect app ID).
    static let appStoreURL = "https://apps.apple.com/app/redmed/id0000000000"

    /// Product kill switch for CoreNFC write/read sessions only.
    /// Owner still always sees the NFC tab (ContentView.showsNFC); scanners never do.
    /// Keep `false` until paid Apple Developer NFC entitlement is restored —
    /// see `RedMed-Xcode/NFC-RESTORE.md` and `RedMed.entitlements`.
    static let nfcHardwareEnabled = false

    /// Hardware RF contract for the RedMed bracelet.
    /// - Band is **passive**: no battery, no BLE/Wi‑Fi radio; the paired phone
    ///   only energises it during an intentional CoreNFC write/scan.
    /// - Band RF is **HF NFC at 13.56 MHz** (ISO 14443 / NTAG NDEF) — a different
    ///   carrier from phone Bluetooth (~2.4 GHz). Do not source LF (~125 kHz)
    ///   or UHF (~860–960 MHz) chips; iPhone CoreNFC cannot program those.
    /// - Contactless payment POS also uses 13.56 MHz but speaks EMV, not NDEF
    ///   medical URLs — protocol separation, not a distance knob.
    /// - Distances below describe HF NFC physics, not a tunable app setting.
    ///   Walk-by / hand nearby (~6–8″) does not fire. Deliberate antenna tap
    ///   is ~1–2″. Beyond ~4″ you are already outside reliable ISO 14443 coupling.
    enum BraceletRF {
        static let carrierMHz: Double = 13.56
        static let family = "ISO 14443 / NFC Forum Type 2 (NTAG213+)"
        static let isPassive = true
        static let usesBluetooth = false
        /// RedMed never starts NFC because a hand or band is merely nearby.
        static let requiresExplicitUserSession = true
        /// Walk-by / casual standoff (inches). Physics already drops off past ~4″;
        /// 6–8″ is enough product margin. Not a tunable read range.
        static let walkByStandoffInchesMin = 6
        static let walkByStandoffInchesMax = 8
        /// Intentional phone-antenna tap range (inches) — real HF NFC coupling.
        static let intentionalTapInchesMin = 1
        static let intentionalTapInchesMax = 2
        /// Beyond this, ISO 14443 coupling on a phone is unreliable.
        static let reliableCouplingInchesMax = 4
        /// Payment terminals speak EMV; they do not open RedMed NDEF URLs.
        static let ignoredByPaymentPOS = true
    }
}
