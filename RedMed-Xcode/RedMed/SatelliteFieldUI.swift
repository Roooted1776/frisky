import UIKit

/// Find Help public emergency dial — **dial only**.
///
/// Hard rules (HIPAA / local-only forever):
/// - Opens the system Phone app to `EmergencyNumber` via `tel:` — nothing else.
/// - Never attaches name, DOB, blood type, allergies, meds, conditions, contacts,
///   GPS, or any other profile / PII / PHI to the call or to any outbound payload.
/// - No SMS composer, no URLSession, no RedMed server, no Bluetooth, no sat SDK.
enum PublicEmergencyAid {
    static func dial() {
        guard let url = EmergencyNumber.dialURL else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
