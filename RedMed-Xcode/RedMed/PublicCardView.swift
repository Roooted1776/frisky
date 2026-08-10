import SwiftUI
import CoreLocation

/// Scanner / first-responder shell.
/// Full RedMed **911** and **Aid** tabs (same as the owner app), plus a read-only Medical ID.
/// No owner Edit / settings — scanners cannot change the profile.
struct PublicCardView: View {
    @ObservedObject var profile: ProfileData
    @Environment(\.dismiss) var dismiss
    @State private var tab: ScannerTab = .emergency

    private enum ScannerTab {
        case medical, emergency, aid
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                scannerChrome

                Group {
                    switch tab {
                    case .medical:
                        ScannerMedicalIDView(profile: profile)
                    case .emergency:
                        EmergencyView()
                    case .aid:
                        AidView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 64)
            }

            scannerTabBar
        }
        .environmentObject(profile)
        .ignoresSafeArea(edges: .bottom)
    }

    private var scannerChrome: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.redmedDark)
            Text("Read only — Medical ID, 911, and Aid. Editing needs the owner’s app + Face ID / passcode.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Close") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.redmedMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    private var scannerTabBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(red: 0.9, green: 0.9, blue: 0.9))
            HStack(spacing: 0) {
                TabBarItem(icon: "person.fill", label: "Medical ID", isOn: tab == .medical) { tab = .medical }
                TabBarItem(icon: "phone.fill", label: "911", isOn: tab == .emergency) { tab = .emergency }
                TabBarItem(icon: "cross.case.fill", label: "Aid", isOn: tab == .aid) { tab = .aid }
            }
            .padding(.top, 2)

            Capsule()
                .fill(Color(red: 0.11, green: 0.098, blue: 0.086).opacity(0.18))
                .frame(width: 134, height: 5)
                .padding(.top, 2)
                .padding(.bottom, 4)
        }
        .background(Color.white)
    }
}

// MARK: - Read-only Medical ID (scanner)

private struct ScannerMedicalIDView: View {
    @ObservedObject var profile: ProfileData

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                identityBlock
                cardSection(title: "Allergies", items: profile.hasData ? profile.allergies : [], critical: true)
                cardSection(title: "Medications", items: profile.hasData ? profile.medications : [], critical: false)
                cardSection(title: "Conditions", items: profile.hasData ? profile.conditions : [], critical: false)
                donorBlock
                contactsBlock
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color.redmedBg)
    }

    private var identityBlock: some View {
        HStack(spacing: 10) {
            Image("BrandLogo")
                .resizable().frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.hasData ? profile.name : "No profile on this card")
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
