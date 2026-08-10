import SwiftUI

/// First-launch consent — mirrors the web app's one-time banner so App Review
/// sees the same privacy posture as the hosted card page.
struct UseConsentView: View {
    @Environment(\.layoutMetrics) private var layout

    let onAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: layout.spaceXL) {
                BrandMark(size: .hero, showTagline: true)
                    .padding(.top, layout.spaceSM)

                VStack(alignment: .leading, spacing: layout.spaceLG) {
                    SectionEyebrow(text: "Before you continue")

                    Text("RedMed stores your medical profile on this device only. Find 911 uses location (and optional motion assist) only while that screen is open. SOS dials 911 and can SMS contacts via your carrier or POST to a configured third-party API — RedMed has no relay server.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(DesignPagePlacement.consentRegulatory)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Link("Privacy Policy", destination: URL(string: AppConfig.privacyPolicyURL)!)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)

                    Button("Accept", action: onAccept)
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(layout.spaceLG)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard(elevated: false)
            }
            .padding(.horizontal, layout.screenPad)
            .padding(.vertical, layout.space2XL)
        }
        .scrollIndicators(.visible, axes: .vertical)
        .screenAtmosphere()
    }
}

#Preview {
    UseConsentView(onAccept: {})
        .withLayoutMetrics()
}
