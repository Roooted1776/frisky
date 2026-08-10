import SwiftUI

/// First-responder NFC path: read a bracelet chip → show `ScannedCardView`.
/// Never touches `ProfileStore` — a scan of someone else's band must not
/// overwrite the owner's My ID.
struct ScanEmergencyCardControl: View {
    var title: String = "Scan emergency bracelet"
    /// When true, uses the prominent red primary button (911 screen).
    var prominent: Bool = false

    @StateObject private var reader = NFCReader()

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if prominent {
                    Button(action: startScan) {
                        label
                    }
                    .buttonStyle(PrimaryButtonStyle(prominent: true))
                } else {
                    Button(action: startScan) {
                        label
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .disabled(reader.isReading)

            if !reader.statusMessage.isEmpty {
                Text(reader.statusMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var label: some View {
        Label(
            reader.isReading ? "Hold near bracelet…" : title,
            systemImage: "wave.3.right.circle.fill"
        )
    }

    private func startScan() {
        reader.readTag(
            alertMessage: "Hold your iPhone near the person's RedMed bracelet to open their emergency card."
        ) { profile, _ in
            NotificationCenter.default.post(name: .redMedShowEmergencyCard, object: profile)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ScanEmergencyCardControl(prominent: true)
        ScanEmergencyCardControl()
    }
    .padding()
    .withLayoutMetrics()
}
