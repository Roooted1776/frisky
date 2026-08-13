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
    /// Setup QR only — never written to the NFC band (band carries `#d=` only).
    static let appStoreURL = "https://apps.apple.com/app/redmed/id0000000000"

    /// Owner band NDEF contract (permanent): write only
    /// `medicalCardBaseURL + "#d=" + base64url`. Profile stays in the fragment —
    /// no vendor tag-management cloud, no social/short-link redirect, no BLE.
    /// Pages hosts the static shell; PHI never leaves the `#d=` fragment.
    enum OwnerBandURI {
        /// NFC tab fact line — single source for “data independence” copy.
        static var dataIndependenceSummary: String {
            "Owner writes #d= on-chip — no vendor cloud, no social/short URL, no BLE."
        }

        /// True only for live owner writes: exact tapper base + non-empty `#d=` payload.
        static func isValidWriteURL(_ urlString: String) -> Bool {
            let base = AppConfig.medicalCardBaseURL
            guard urlString.hasPrefix(base) else { return false }
            let rest = urlString.dropFirst(base.count)
            guard rest.hasPrefix("#d=") else { return false }
            let payload = rest.dropFirst(3)
            guard !payload.isEmpty else { return false }
            // Fragment only — reject query smuggling / second hashes / whitespace.
            if payload.contains(where: { $0 == "#" || $0 == "?" || $0 == " " || $0 == "\n" || $0 == "\r" }) {
                return false
            }
            // AES-GCM wire is base64url (A–Z a–z 0–9 - _).
            return payload.unicodeScalars.allSatisfy { scalar in
                switch scalar.value {
                case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x5F: return true
                default: return false
                }
            }
        }
    }

    /// Product kill switch for CoreNFC write/read sessions only.
    /// Owner still always sees the NFC tab (ContentView.showsNFC); scanners never do.
    /// Keep `false` until paid Apple Developer NFC entitlement is restored —
    /// see `docs/NFC-RESTORE.md` and `RedMed.entitlements`.
    static let nfcHardwareEnabled = false

    /// Hardware RF contract for the RedMed bracelet.
    /// - Band is **passive**: no battery, no BLE/Wi‑Fi radio. RedMed only starts
    ///   CoreNFC on explicit Write/Scan. Separately, iOS Background Tag Reading
    ///   can energise a written NDEF URI tag on a deliberate tap even when the
    ///   phone is off or locked (antenna ~top ~1–2″ from the band) — RedMed
    ///   cannot disable that OS path. Write does not change BTR likelihood.
    ///   Band stays passive — no battery (not AirTag / BLE).
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

        /// RedMed session behaviour — not Apple Background Tag Reading.
        static var powerOnTapSummary: String {
            "RedMed does not keep a background NFC pair. Chip is passive — no Bluetooth."
        }

        /// What can still open the URL later (Apple OS path; phone off / locked OK).
        static var backgroundTagReadingSummary: String {
            "iOS Background Tag Reading can still open the card later — phone can be off or locked; a deliberate tap (phone top \(intentionalTapRangeLabel) from the band) still works. Wrist + pocket is usually fine. Phone pressed to the clasp can pop Safari. Same for any passerby. Writing the chip does not change that. Band stays passive — no battery."
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

        /// Alias for NFC / sourcing copy — band is never a BLE device.
        static var noBluetoothSummary: String { carrierVsBluetoothSummary }
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
