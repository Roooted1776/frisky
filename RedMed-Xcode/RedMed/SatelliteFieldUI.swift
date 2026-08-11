import SwiftUI
import UIKit

/// System dial / SMS for Find Help — no RedMed network, no Bluetooth, no profile attach.
enum PublicEmergencyAid {
    private static let smsBody = "Emergency — need public aid."

    static func dial() {
        guard let url = EmergencyNumber.dialURL else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    static func text() {
        let encoded = smsBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "sms:\(EmergencyNumber.current)&body=\(encoded)") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
