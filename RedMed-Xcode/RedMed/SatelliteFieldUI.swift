import SwiftUI
import UIKit

/// Find Help public-aid path when terrestrial cell is weak or down.
///
/// **Starlink Direct-to-Cell has no app API.** Compatible phones on participating
/// carriers (e.g. T-Mobile in the US) may reach a Starlink satellite as if it were
/// a cell tower. RedMed only opens the system Phone / Messages sheet for the
/// regional public emergency number (`EmergencyNumber`) — iOS + the carrier pick
/// the radio (terrestrial or DTC). No PHI is sent to RedMed or to a Starlink SDK.
struct StarlinkDirectAidCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 15))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.redmedAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Public Aid · Satellite Path")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedDark)
            }

            Text("Calls \(EmergencyNumber.current) through the Phone app. On T-Mobile (and other Starlink Direct-to-Cell carriers listed under No cell signal), the handset may use a satellite when towers are down — hiking, canyons, remote roads. RedMed cannot select that radio. No RedMed server. No profile upload.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .lineSpacing(3)

            Button {
                StarlinkPublicAid.dialEmergencyServices()
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
                StarlinkPublicAid.textEmergencyServices()
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

            Text("Text-to-\(EmergencyNumber.current) only where your region supports it. If SMS fails, use Call or Apple Emergency SOS (Side + Volume). Clear view of the sky helps any satellite path.")
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

/// System dial / SMS only — no Starlink SDK, no outbound PHI from RedMed.
enum StarlinkPublicAid {
    /// Non-PHI SMS body. Location / medical ID stay on-device unless the user
    /// speaks them on the call or pastes coords themselves.
    private static let smsBody = "Emergency — need public aid. RedMed user."

    static func dialEmergencyServices() {
        guard let url = EmergencyNumber.dialURL else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    static func textEmergencyServices() {
        let encoded = smsBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "sms:\(EmergencyNumber.current)&body=\(encoded)") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
