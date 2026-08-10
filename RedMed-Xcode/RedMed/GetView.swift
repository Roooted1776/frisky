import SwiftUI

/// Persists owner acceptance of the Get / band-setup gate. NFC tab stays hidden until true.
final class NFCAccessGate: ObservableObject {
    static let shared = NFCAccessGate()
    private static let defaultsKey = "redmed.nfcSetupAccepted"

    @Published var isAccepted: Bool {
        didSet { UserDefaults.standard.set(isAccepted, forKey: Self.defaultsKey) }
    }

    private init() {
        isAccepted = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    func accept() {
        isAccepted = true
    }
}

/// SwiftUI port of repo-root `get.html` — “Set up your RedMed band”.
/// Must Accept here before the NFC tab / page becomes visible.
struct GetView: View {
    /// Called after Accept (e.g. dismiss sheet and open NFC).
    var onAccept: (() -> Void)? = nil

    private let cardBg = Color.white.opacity(0.05)
    private let cardBorder = Color.white.opacity(0.08)
    private let muted = Color.white.opacity(0.75)
    private let dim = Color.white.opacity(0.30)
    private let support = Color.white.opacity(0.35)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                getCard
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.039, green: 0.039, blue: 0.039).ignoresSafeArea())
        .navigationTitle("Set up your band")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var getCard: some View {
        VStack(spacing: 0) {
            Text("RedMed")
                .font(.system(size: 28, weight: .heavy))
                .kerning(-0.6)
                .foregroundColor(.redmedAccent)
                .padding(.bottom, 4)

            heroWell
                .padding(.top, 24)
                .padding(.bottom, 20)

            Text("Tap the band — phone opens your emergency card. No app for readers.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 12)

            Text("IPHONE")
                .font(.system(size: 11, weight: .bold))
                .kerning(0.8)
                .foregroundColor(.redmedAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.redmedAccent.opacity(0.12))
                        .overlay(Capsule().stroke(Color.redmedAccent.opacity(0.25), lineWidth: 1))
                )
                .padding(.bottom, 20)

            Button {
                NFCAccessGate.shared.accept()
                onAccept?()
            } label: {
                Text("Accept")
                    .font(.system(size: 16, weight: .bold))
                    .kerning(-0.2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.984, green: 0.443, blue: 0.522), .redmedAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.redmedAccent.opacity(0.25), radius: 7, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            stepsList
                .padding(.top, 20)

            Text("Accept to unlock the NFC page and program your band on this iPhone.")
                .font(.system(size: 12))
                .foregroundColor(dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 16)

            Text("Passive NFC only — no battery, no broadcast. RedMed is not a medical device. In an emergency, call \(EmergencyNumber.current).")
                .font(.system(size: 12))
                .foregroundColor(dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 16)

            Link("help.RedMed@gmail.com", destination: URL(string: "mailto:help.RedMed@gmail.com")!)
                .font(.system(size: 13))
                .foregroundColor(support)
                .padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 32)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
    }

    private var heroWell: some View {
        ZStack {
            Circle()
                .stroke(Color.redmedAccent.opacity(0.2), lineWidth: 1.5)
                .frame(width: 88, height: 88)
            Circle()
                .fill(Color.redmedAccent.opacity(0.1))
                .frame(width: 68, height: 68)
            Image(systemName: "wave.3.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.redmedAccent)
        }
        .frame(width: 88, height: 88)
        .accessibilityHidden(true)
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepRow(1, "Open RedMed on iPhone and fill in your allergies, meds, and contacts.")
            stepRow(2, "Hold your band to the top of your iPhone once — the chip stores your emergency card.")
            stepRow(3, "Done. Anyone taps the band — their phone opens Call \(EmergencyNumber.current) and your critical info. No app needed.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.redmedAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.redmedAccent.opacity(0.15)))
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
