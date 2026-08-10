import SwiftUI
import CoreLocation
import UIKit

/// First-responder emergency card — bracelet scan / deep link.
/// Instant: Call 911 + medical ID first, then GPS, then roadside aid.
/// Never shows NFC setup. Never writes to the device owner's ProfileStore.
struct ScannedCardView: View {
    @Environment(\.layoutMetrics) private var layout

    let profile: MedicalProfile
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var copiedSummary = false
    @State private var copiedCoords = false
    @State private var traumaExpanded = false
    @State private var openPaneId: String?
    @State private var aidPath = NavigationPath()

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

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: layout.spaceMD),
            GridItem(.flexible(), spacing: layout.spaceMD)
        ]
    }

    var body: some View {
        NavigationStack(path: $aidPath) {
            ScrollView {
                LazyVStack(spacing: 0) {
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
                            UIPasteboard.general.string = EmergencySummaryBuilder.build(
                                profile: profile,
                                coordinate: locationManager.coordinate,
                                accuracy: locationManager.accuracy,
                                heading: locationManager.heading,
                                altitude: locationManager.altitude,
                                locationTimestamp: locationManager.locationTimestamp
                            )
                            copiedSummary = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedSummary = false
                            }
                        } label: {
                            Text(copiedSummary ? "Copied!" : "Copy medical + GPS summary")
                        }
                        .buttonStyle(InkButtonStyle())

                        // --- Find 911 GPS ---
                        gpsBlock

                        // --- Roadside Aid (no NFC) ---
                        VStack(alignment: .leading, spacing: layout.spaceSM) {
                            SectionEyebrow(text: "Roadside Aid", tint: AppTheme.accent)
                            Text("Call 911 first. Tap a pane — expand only what you need.")
                                .font(layout.captionFont(weight: .medium))
                                .foregroundStyle(AppTheme.muted)

                            LazyVGrid(columns: columns, spacing: layout.spaceMD) {
                                ForEach(AidPaneLibrary.panes) { pane in
                                    scannerAidPane(pane)
                                        .gridCellColumns(openPaneId == pane.id ? 2 : 1)
                                }
                            }
                        }

                        DisclosureGroup(isExpanded: $traumaExpanded) {
                            TraumaHospitalsSection(gpsCoordinate: locationManager.coordinate)
                        } label: {
                            Text("Trauma center transport")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                        }

                        Text("Scanner view: medical ID, 911, and roadside aid. NFC setup is not shown. Nothing saved to this phone.")
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
            .navigationDestination(for: FirstAidTopic.self) { topic in
                FirstAidDetailView(topic: topic)
            }
            .task { locationManager.requestLocation() }
            .onDisappear { locationManager.stopUpdating() }
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

    private var gpsBlock: some View {
        VStack(alignment: .leading, spacing: layout.spaceSM) {
            SectionEyebrow(text: "Live GPS", tint: AppTheme.medical)
            if let c = locationManager.coordinate {
                Text(String(format: "%.6f, %.6f", c.latitude, c.longitude))
                    .font(.system(size: layout.s(18), design: .monospaced).weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                if let acc = locationManager.accuracy, acc > 0 {
                    Text(String(format: "Accuracy ±%.0f m", acc))
                        .font(layout.captionFont(weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                }
                Button {
                    UIPasteboard.general.string = LocationFormatting.coordsCopyText(
                        latitude: c.latitude,
                        longitude: c.longitude
                    )
                    copiedCoords = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedCoords = false }
                } label: {
                    Text(copiedCoords ? "Copied!" : "Copy coordinates")
                }
                .buttonStyle(InkButtonStyle())
            } else {
                ProgressView("Getting GPS…")
                    .tint(AppTheme.medical)
            }
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    @ViewBuilder
    private func scannerAidPane(_ pane: AidPane) -> some View {
        let isOpen = openPaneId == pane.id
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    openPaneId = isOpen ? nil : pane.id
                }
            } label: {
                HStack(spacing: layout.spaceMD) {
                    Text(pane.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(layout.s(14))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: layout.spaceSM) {
                    ForEach(pane.topics) { topic in
                        Button {
                            aidPath.append(topic)
                        } label: {
                            HStack {
                                Text(topic.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .padding(.horizontal, layout.s(12))
                            .padding(.vertical, layout.s(10))
                            .background(Color.white.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: layout.innerRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, layout.s(10))
                .padding(.bottom, layout.s(12))
            }
        }
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: layout.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cardRadius, style: .continuous)
                .stroke(isOpen ? AppTheme.accent.opacity(0.28) : AppTheme.line, lineWidth: 1)
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
