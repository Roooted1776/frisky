import SwiftUI
import UIKit

/// First-responder emergency card — shown when a bracelet is scanned in-app
/// (NFC session or legacy `redmed://` / HTTPS `#d=` deep link). Displays THAT
/// tag's decoded profile, never the device owner's `ProfileStore`. Read-only:
/// a responder must not be able to overwrite the owner's My ID from here.
struct ScannedCardView: View {
    @Environment(\.layoutMetrics) private var layout

    let profile: MedicalProfile
    @Environment(\.dismiss) private var dismiss
    @State private var copiedSummary = false
    @State private var traumaExpanded = false

    private var ageLine: String {
        var parts: [String] = []
        if let age = ageYears(from: profile.dob) {
            parts.append("\(age) yrs")
        }
        if !profile.dob.isEmpty {
            parts.append("DOB \(profile.dob)")
        }
        if !profile.blood.isEmpty {
            parts.append("Blood \(profile.blood)")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: layout.s(18)) {
                        Call911Button()

                        if !profile.allergies.isEmpty {
                            criticalBlock(title: "Allergies", items: profile.allergies)
                        }
                        if !profile.meds.isEmpty {
                            infoBlock(title: "Medications", items: profile.meds)
                        }
                        if !profile.conditions.isEmpty {
                            infoBlock(title: "Medical conditions", items: profile.conditions)
                        }

                        let contacts = profile.contacts.filter { !$0.name.isEmpty || !$0.phone.isEmpty }
                        if !contacts.isEmpty {
                            contactsBlock(contacts)
                        }

                        Button {
                            UIPasteboard.general.string = EmergencySummaryBuilder.build(profile: profile)
                            copiedSummary = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedSummary = false
                            }
                        } label: {
                            Text(copiedSummary ? "Copied!" : "Copy medical summary")
                        }
                        .buttonStyle(InkButtonStyle())

                        DisclosureGroup(isExpanded: $traumaExpanded) {
                            TraumaHospitalsSection()
                        } label: {
                            Text("Trauma center transport")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                        }

                        Text("Tap the band → this card. Nothing saved to this phone.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        if profile.allergies.isEmpty,
                           profile.meds.isEmpty,
                           profile.conditions.isEmpty,
                           contacts.isEmpty {
                            Text("No allergies, meds, conditions, or contacts were written to this band.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(layout.screenPad)
                    .padding(.bottom, layout.s(28))
                }
                .reactiveScrollTrack()
            }
            .reactiveScrollChrome()
            .scrollIndicators(.visible, axes: .vertical)
            .background(AppTheme.pageBg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EMERGENCY CARD")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.muted)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: layout.s(10)) {
            Text("REDMED")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.85))

            Text(profile.name.isEmpty ? "Medical ID" : profile.name)
                .font(layout.emergencyNameFont())
                .tracking(-0.5)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if !ageLine.isEmpty {
                Text(ageLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            }

            if profile.donor {
                Text("Organ donor")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, layout.s(10))
                    .padding(.vertical, layout.s(5))
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, layout.spaceXS)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, layout.screenPad)
        .padding(.top, layout.s(28))
        .padding(.bottom, layout.screenBottomLarge)
        .background(
            LinearGradient(
                colors: [AppTheme.accent, Color(red: 0.75, green: 0.07, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func criticalBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: layout.s(10)) {
            SectionEyebrow(text: title, tint: AppTheme.accent)
            VStack(alignment: .leading, spacing: layout.spaceSM) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: layout.s(10)) {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: layout.bulletDot, height: layout.bulletDot)
                            .padding(.top, layout.s(7))
                        Text(item)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(layout.s(14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: layout.innerRadius, style: .continuous))
        }
    }

    private func infoBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: layout.s(10)) {
            SectionEyebrow(text: title, tint: AppTheme.muted)
            VStack(alignment: .leading, spacing: layout.spaceSM) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: layout.s(10)) {
                        Circle()
                            .fill(AppTheme.medical)
                            .frame(width: layout.bulletDot, height: layout.bulletDot)
                            .padding(.top, layout.s(7))
                        Text(item)
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func contactsBlock(_ contacts: [EmergencyContact]) -> some View {
        VStack(alignment: .leading, spacing: layout.s(10)) {
            SectionEyebrow(text: "Emergency contacts", tint: AppTheme.muted)
            VStack(spacing: layout.s(10)) {
                ForEach(contacts) { contact in
                    HStack(spacing: layout.spaceMD) {
                        VStack(alignment: .leading, spacing: layout.s(2)) {
                            Text(contact.name.isEmpty ? "Contact" : contact.name)
                                .font(.body.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                            if !contact.rel.isEmpty {
                                Text(contact.rel)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            if !contact.phone.isEmpty {
                                Text(contact.phone)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                        Spacer(minLength: layout.spaceSM)
                        if !contact.phone.isEmpty,
                           let url = URL(string: "tel:\(contact.phone.filter { $0.isNumber || $0 == "+" })") {
                            Link(destination: url) {
                                Text("Call")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, layout.spaceLG)
                                    .padding(.vertical, layout.s(10))
                                    .background(AppTheme.medical)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(layout.s(14))
                    .appCard(elevated: false)
                }
            }
        }
    }

    private func ageYears(from dob: String) -> Int? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dob) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year
    }
}

#Preview {
    ScannedCardView(profile: MedicalProfile(
        name: "Alex Rivera",
        dob: "1990-04-12",
        blood: "O+",
        donor: true,
        allergies: ["Penicillin"],
        meds: ["Metformin 500mg"],
        conditions: ["Type 2 diabetes"],
        contacts: [EmergencyContact(name: "Sam Rivera", rel: "Spouse", phone: "5551234567")]
    ))
    .withLayoutMetrics()
}
