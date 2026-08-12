import Foundation

enum AppConfig {
    /// Passerby / rescuer shell written to passive NFC bands. Any phone that taps
    /// the bracelet opens this page in a browser — read-only medical card + 911 +
    /// Aid. No Face ID to view. Medical data is only in the `#d=` fragment (flat
    /// array → AES-GCM → base64url; no server storage). `sw.js` cache-first stores
    /// the static layout for instant offline / EMT taps (activate clears prior
    /// CACHE buckets). Owner edit / treatments live in `Main.swift`, not here.
    /// Source page: `tapper.html` / `tapper/index.html` (identical at `tapper/`, repo root,
    /// and `RedMed-Xcode/RedMed/tapper.html`). Legacy `card/` / `get/` URLs redirect to `/tapper/`
    /// (preserve `#d=`). Owner Preview / Scan always use the **bundled** tapper.html
    /// (local-only). Hosted Pages must serve the tapper shell (RedMed · 911 · Aid).
    /// Local: `./scripts/deploy-pages.sh`. Live: `DEPLOY=1` + CF tokens, or the
    /// `Pages tapper deploy` GitHub Action on `main`.
    static let medicalCardBaseURL = "https://redmed.pages.dev/tapper/"

    /// Deep link target for policy / card HTML “open owner app” redirects.
    static let mainAppURL = "redmed://main"

    /// Update when the App Store listing is live (App Store Connect app ID).
    static let appStoreURL = "https://apps.apple.com/app/redmed/id0000000000"

    /// Product kill switch for CoreNFC write/read sessions only.
    /// Owner still always sees the NFC tab (ContentView.showsNFC); scanners never do.
    /// Keep `false` until paid Apple Developer NFC entitlement is restored —
    /// see `docs/NFC-RESTORE.md` and `RedMed.entitlements`.
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

        // MARK: Product copy (single source — do not hardcode distances elsewhere)

        static var carrierLabel: String {
            String(format: "%.2f MHz HF NFC", carrierMHz)
        }

        static var walkByRangeLabel: String {
            "~\(walkByStandoffInchesMin)–\(walkByStandoffInchesMax)″"
        }

        static var intentionalTapRangeLabel: String {
            "~\(intentionalTapInchesMin)–\(intentionalTapInchesMax)″"
        }

        static var reliableCouplingLabel: String {
            "~\(reliableCouplingInchesMax)″"
        }

        /// NFC tab status line: walk-by vs deliberate tap.
        static var tapDistanceSummary: String {
            "Walk-by won't fire (\(walkByRangeLabel)). Only a deliberate \(intentionalTapRangeLabel) antenna tap opens the card."
        }

        static var carrierVsBluetoothSummary: String {
            "Passive band · \(carrierLabel) (NTAG) — not Bluetooth 2.4 GHz."
        }

        static var powerOnTapSummary: String {
            "Phone only powers the chip on write/scan. No background pair radio."
        }

        static var paymentPOSSummary: String {
            "POS ignore this chip (EMV ≠ NDEF) — not a distance setting."
        }

        static var passerbyTapSummary: String {
            "Tap to scan — card opens in the browser. Quick. No login. No server. No app for helpers."
        }

        /// How It Works / setup prose for intentional tap vs walk-by.
        static var writeBandDistanceBlurb: String {
            "Walk-by distance will not fire the band; only a deliberate \(intentionalTapRangeLabel) antenna tap opens the card."
        }
    }

    /// Carrier notes + local-only rule for Find Help.
    /// Call uses system `tel:` only — never attaches profile / PII / PHI / GPS.
    enum Satellite {
        /// Permanent product rule — do not soften or time-box.
        static let localOnlyLine =
            "Local only once tap — everyone and everything. No servers · no online. No Bluetooth · passive HF NFC. No PII or PHI leaves this device through RedMed."

        /// Compact Find Help line — full partner roster lives in legal copy, not the field UI.
        static let directToCellCarriersLine =
            "T-Mobile (US) + Starlink Direct-to-Cell partners — plan/region required; not a coverage promise."
    }
}
