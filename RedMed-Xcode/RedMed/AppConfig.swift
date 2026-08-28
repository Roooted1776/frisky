import Foundation

enum AppConfig {
    static let medicalCardCustomDomainTBD: String? = nil

    static var medicalCardBaseURL: String {
        if let custom = medicalCardCustomDomainTBD?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom.hasSuffix("/") ? custom : custom + "/"
        }
        return "https://roooted1776.github.io/tapper/"
    }

    static let mainAppURL = "redmed://main"
    static let nfcTabURL = "redmed://nfc"
    static let appStoreURL: String? = nil
    static let supportURL = "https://cdn.jsdelivr.net/gh/Roooted1776/redmed-privacy@main/support.html"
    static let privacyPolicyURL = "https://cdn.jsdelivr.net/gh/Roooted1776/redmed-privacy@main/index.html"

    enum OwnerBandURI {
        static var dataIndependenceSummary: String {
            "Owner writes #d= on-chip — no vendor cloud, no social/short URL, no BLE."
        }

        nonisolated static func isValidWriteURL(_ urlString: String) -> Bool {
            let base = AppConfig.medicalCardBaseURL
            guard urlString.hasPrefix(base) else { return false }
            let rest = urlString.dropFirst(base.count)
            guard rest.hasPrefix("#d=") else { return false }
            let payload = rest.dropFirst(3)
            guard !payload.isEmpty else { return false }
            if payload.contains(where: { $0 == "#" || $0 == "?" || $0 == " " || $0 == "\n" || $0 == "\r" }) {
                return false
            }
            return payload.unicodeScalars.allSatisfy { scalar in
                switch scalar.value {
                case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x5F: return true
                default: return false
                }
            }
        }
    }

    static let nfcHardwareEnabled = false
    static let healthKitImportEnabled = false

    enum BraceletRF {
        static let carrierMHz: Double = 13.56
        static let chipPart = "NXP NTAG216"
        static let family = "ISO 14443A Type 2 (NXP NTAG216)"
        static let laserFace = "MED ID"
        static let isPassive = true
        static let isRewritable = true
        static let factoryPreEncode = false
        static let factoryLock = false
        static let usesBluetooth = false
        static let requiresExplicitUserSession = true
        static let walkByStandoffInchesMin = 6
        static let walkByStandoffInchesMax = 8
        static let intentionalTapInchesMin = 1
        static let intentionalTapInchesMax = 2
        static let reliableCouplingInchesMax = 4
        static let ignoredByPaymentPOS = true

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

        static var tapDistanceSummary: String {
            "Walk-by won't fire (\(walkByRangeLabel)). Only a deliberate \(intentionalTapRangeLabel) antenna tap opens the card."
        }

        static var carrierVsBluetoothSummary: String {
            "Passive \(chipPart) · \(carrierLabel) · ISO 14443A Type 2 — not Bluetooth 2.4 GHz."
        }

        static var chipSpecSummary: String {
            "\(chipPart), \(carrierLabel), ISO 14443A Type 2, NDEF blank unlocked. No pre-encode, no lock. Not NTAG213, MIFARE, LF, or UHF."
        }

        static var laserFaceSummary: String {
            "Laser face: \(laserFace) only."
        }

        static var rewritableBandSummary: String {
            "NDEF blank unlocked — owner Write programs the band. Factory does not pre-encode or lock."
        }

        static var powerOnTapSummary: String {
            "RedMed does not keep a background NFC pair. Chip is passive — no Bluetooth."
        }

        static var backgroundTagReadingSummary: String {
            "iOS Background Tag Reading can still open the card later — phone can be off or locked; a deliberate tap (phone top \(intentionalTapRangeLabel) from the band) still works. Safari opens the tap card immediately — no Face ID, no login, no app. Wrist + pocket is usually fine. Phone pressed to the clasp can pop Safari. Same for any passerby. Writing the chip does not change that. Band stays passive — no battery."
        }

        static var paymentPOSSummary: String {
            "POS ignore this chip (EMV ≠ NDEF) — not a distance setting."
        }

        static var passerbyTapSummary: String {
            "Tap to scan — card opens in the browser. Quick. No login. No server. No app for helpers."
        }

        static var writeBandDistanceBlurb: String {
            "Walk-by distance will not fire the band; only a deliberate \(intentionalTapRangeLabel) antenna tap opens the card."
        }

        static var noBluetoothSummary: String { carrierVsBluetoothSummary }

        static var hardwareParkedSummary: String {
            "Band write is preview-only in this build. CoreNFC ships when NFC Tag Reading is on the App ID. Preview still shows the helper card from this iPhone."
        }
    }

    enum QuietPrayer {
        static let fontSize: CGFloat = 11
        static let text =
            "Stay calm. Call emergency services.\nFollow the dispatcher."
    }

    enum AidCopy {
        static let referenceDisclaimer =
            "First-aid reference only. Not medical advice and not a substitute for emergency dispatch. Call emergency services and follow their instructions."
    }

    enum Satellite {
        static let localOnlyLine =
            "Local only once tap — everyone and everything. No servers · no online. No Bluetooth · passive HF NFC. No PII or PHI leaves this device through RedMed."
    }
}
