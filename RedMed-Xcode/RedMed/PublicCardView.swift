import SwiftUI
import CoreLocation

/// Instant read-only surface for bracelet scanners / first responders.
/// Shows: medical ID, Find 911 actions (dial + GPS + contacts), Roadside Aid.
/// Does **not** show NFC setup — that tab is owner-only.
struct PublicCardView: View {
    @ObservedObject var profile: ProfileData
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationHelper = LocationHelper()
    @State private var openAidPane: String?
    @State private var activeTopic: AidTopic?

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    banner

                    readOnlyLock

                    // --- 911 first (instant) ---
                    PrimaryButton(title: "Call 911") {
                        if let url = URL(string: "telprompt:911") { UIApplication.shared.open(url) }
                    }

                    SecondaryButton("Text location to emergency contact") {
                        locationHelper.requestAndSend(to: profile.contacts.first?.detail)
                    }

                    // --- User medical ID ---
                    identityBlock
                    cardSection(title: "Allergies", items: profile.hasData ? profile.allergies : [], critical: true)
                    cardSection(title: "Medications", items: profile.hasData ? profile.medications : [], critical: false)
                    cardSection(title: "Conditions", items: profile.hasData ? profile.conditions : [], critical: false)
                    donorBlock
                    contactsBlock

                    // --- Find 911 (GPS) ---
                    SectionLabel(text: "Live GPS")
                    GPSCard(location: locationManager.location)
                    Button {
                        if let loc = locationManager.location {
                            UIPasteboard.general.string =
                                "\(loc.coordinate.latitude), \(loc.coordinate.longitude)"
                        }
                    } label: {
                        Text("Copy coordinates")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.redmedDark)
                            .clipShape(Capsule())
                    }

                    // --- Roadside Aid (no NFC) ---
                    SectionLabel(text: "Roadside Aid")
                    Text("Call 911 first. Tap a pane — expand only what you need.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.redmedMuted)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(aidPanes.filter { $0.id != "hospitals" }) { pane in
                            let isOpen = openAidPane == pane.id
                            PaneCard(pane: pane, isOpen: isOpen) { key in
                                if key == nil {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        openAidPane = isOpen ? nil : pane.id
                                    }
                                } else if let k = key, let topic = aidTopics[k] {
                                    activeTopic = topic
                                }
                            }
                            .gridCellColumns(isOpen ? 2 : 1)
                        }
                    }

                    Text("Scanner view — medical ID, 911, and roadside aid only. NFC setup is hidden. This card cannot be edited here.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                .padding(16)
            }
            .background(Color(red: 0.949, green: 0.949, blue: 0.969))
            .navigationTitle("Emergency Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(.redmedMuted)
                }
            }
            .task { locationManager.start() }
            .onDisappear { locationManager.stop() }
            .sheet(item: $activeTopic) { topic in
                TopicDetailView(topic: topic)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var banner: some View {
        HStack(spacing: 8) {
            Image(systemName: "cross.case.fill")
                .foregroundColor(.redmedAccent)
            Text("Emergency card — medical ID · 911 · roadside aid")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.redmedAccent)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.redmedAccent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Scanners cannot alter the band or profile from this surface.
    private var readOnlyLock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.redmedDark)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Read only")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.redmedDark)
                Text("You can’t edit this medical ID from a scan. Changes require the owner’s RedMed app unlocked with Face ID, Touch ID, or device passcode.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.redmedDivider, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
    }

    private var identityBlock: some View {
        HStack(spacing: 10) {
            Image("BrandLogo")
                .resizable().frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.hasData ? profile.name : "No profile on this band")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.redmedDark)
                Text(profile.hasData ? "\(profile.birthDate) · Blood \(profile.bloodType)" : "—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.redmedMuted)
                if !profile.lastUpdated.isEmpty {
                    Text("Updated \(profile.lastUpdated)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.redmedMuted.opacity(0.8))
                }
            }
        }
    }

    private var donorBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Organ donor")
            HStack {
                Text("Registered donor")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                Spacer()
                Text(profile.hasData ? (profile.isOrganDonor ? "Yes" : "No") : "—")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.redmedDark)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var contactsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Emergency contacts")
            VStack(spacing: 0) {
                if !profile.hasData || profile.contacts.isEmpty {
                    Text("—")
                        .font(.system(size: 14))
                        .foregroundColor(.redmedMuted.opacity(0.4))
                        .padding(.horizontal, 16).padding(.vertical, 11)
                } else {
                    ForEach(profile.contacts) { c in
                        Button {
                            let digits = c.detail.filter(\.isNumber)
                            if let url = URL(string: "telprompt:\(digits)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.redmedDark)
                                Text("\(c.detail) · Tap to call")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.redmedAccent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if c.id != profile.contacts.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func cardSection(title: String, items: [String], critical: Bool) -> some View {
        SectionLabel(text: title)
        VStack(spacing: 0) {
            if items.isEmpty {
                Text("—")
                    .font(.system(size: 14))
                    .foregroundColor(.redmedMuted.opacity(0.4))
                    .padding(.horizontal, 16).padding(.vertical, 11)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Text(item)
                        .font(.system(size: 14, weight: critical ? .semibold : .regular))
                        .foregroundColor(critical ? .redmedAccent : .redmedDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(critical ? Color.redmedAccent.opacity(0.06) : Color.clear)
                    if i < items.count - 1 { Divider().padding(.leading, 16) }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
