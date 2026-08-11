import SwiftUI
import UIKit

/// Find Help: open the system Phone / Messages sheet for public emergency aid.
///
/// RedMed product rules: **no Bluetooth, no RedMed servers, passive HF NFC only.**
/// Starlink Direct-to-Cell (if the carrier provides it) is the handset’s radio —
/// not a RedMed uplink and not the bracelet.
struct StarlinkDirectAidCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.redmedAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(AppConfig.Satellite.publicAidTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedDark)
            }

            Text("Opens Call / Text for \(EmergencyNumber.current) in the Phone or Messages app. If your carrier (e.g. T-Mobile) has Starlink Direct-to-Cell, iOS may use that radio when towers are down. RedMed does not pair Bluetooth, does not run a server, and does not send your profile — the band stays passive HF NFC.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .lineSpacing(3)

            Button {
                PublicEmergencyAid.dial()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                    Text("Call \(EmergencyNumber.current)")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.redmedDark)
                .clipShape(Capsule())
            }

            Button {
                PublicEmergencyAid.text()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                    Text("Text \(EmergencyNumber.current)")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.redmedDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.redmedDivider, lineWidth: 1))
            }

            Text(AppConfig.Satellite.localOnlyLine)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .lineSpacing(2)

            Text("Text-to-\(EmergencyNumber.current) only where your region supports it. If SMS fails, Call or use Apple Emergency SOS (Side + Volume) under No cell signal.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
    }
}

/// System dial / SMS only — no RedMed network, no Bluetooth, no profile attach.
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
