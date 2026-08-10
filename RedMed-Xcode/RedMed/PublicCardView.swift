import SwiftUI
import CoreLocation

/// Read-only emergency card — what a stranger sees after tapping the NFC bracelet.
/// Mirrors the static hosted `card/` page: identity, allergies, conditions, contacts, roadside aid.
struct PublicCardView: View {
    @ObservedObject var profile: ProfileData
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationHelper = LocationHelper()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.redmedAccent)
                        Text("Emergency medical card — read only")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.redmedAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    PrimaryButton(title: "Call 911") {
                        if let url = URL(string: "tel://911") { UIApplication.shared.open(url) }
                    }

                    PrimaryButton(title: "Text My Location to Emergency Contact") {
                        locationHelper.requestAndSend(to: profile.contacts.first?.detail)
                    }

                    Text("Profile last updated \(profile.lastUpdated.isEmpty ? "—" : profile.lastUpdated)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.redmedMuted)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack(spacing: 10) {
                        Image("BrandLogo")
                            .resizable().frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.hasData ? profile.name : "No profile on this band")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.redmedDark)
                            Text(profile.hasData ? "\(profile.birthDate) · Blood type \(profile.bloodType)" : "—")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.redmedMuted)
                        }
                    }

                    cardSection(title: "Allergies", items: profile.hasData ? profile.allergies : [])
                    cardSection(title: "Conditions", items: profile.hasData ? profile.conditions : [])
                    cardSection(title: "Medications", items: profile.hasData ? profile.medications : [])

                    SectionLabel(text: "Organ donor status")
                    HStack {
                        Text("Registered donor").font(.system(size: 14, weight: .medium)).foregroundColor(.redmedMuted)
                        Spacer()
                        Text(profile.hasData ? (profile.isOrganDonor ? "Yes" : "No") : "—")
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.redmedDark)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    SectionLabel(text: "Emergency contacts")
                    VStack(spacing: 0) {
                        if !profile.hasData || profile.contacts.isEmpty {
                            Text("—").font(.system(size: 14)).foregroundColor(.redmedMuted.opacity(0.4))
                                .padding(.horizontal, 16).padding(.vertical, 11)
                        } else {
                            ForEach(profile.contacts) { c in
                                Button {
                                    let digits = c.detail.filter(\.isNumber)
                                    if let url = URL(string: "tel://\(digits)") { UIApplication.shared.open(url) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.redmedDark)
                                        Text("\(c.detail) · Tap to call").font(.system(size: 12, weight: .medium)).foregroundColor(.redmedAccent)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16).padding(.vertical, 11)
                                }
                                .buttonStyle(.plain)
                                if c.id != profile.contacts.last?.id { Divider().padding(.leading, 16) }
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Roadside first aid — same content as the static hosted card (not stored on the tag).
                    SectionLabel(text: "Roadside first aid")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick steps while help is on the way. Call 911 first for any life-threatening emergency.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .lineSpacing(3)

                        ForEach(roadsideAidTopics, id: \.id) { topic in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(topic.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.redmedDark)
                                ForEach(Array(topic.care.enumerated()), id: \.offset) { _, step in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.redmedAccent)
                                        Text(step)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.redmedMuted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Text("Generated by RedMed. No account or login needed to view this card. Medical details come from the bracelet; first-aid steps are the same for every band.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color(red: 0.949, green: 0.949, blue: 0.969))
            .navigationTitle("redmed.app/card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(.redmedMuted)
                }
            }
        }
    }

    @ViewBuilder
    func cardSection(title: String, items: [String]) -> some View {
        SectionLabel(text: title)
        VStack(spacing: 0) {
            if items.isEmpty {
                Text("—").font(.system(size: 14)).foregroundColor(.redmedMuted.opacity(0.4))
                    .padding(.horizontal, 16).padding(.vertical, 11)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Text(item).font(.system(size: 14)).foregroundColor(.redmedDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                    if i < items.count - 1 { Divider().padding(.leading, 16) }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
