import SwiftUI

struct MyIDView: View {
    @EnvironmentObject var profile: ProfileData
    @Binding var tab: AppTab
    @State private var showEdit = false
    @State private var showHelp = false
    @State private var showAuthFailedAlert = false

    private var deviceName: String {
        let base = profile.name.isEmpty ? "Your" : profile.name
        return "\(base)'s iPhone"
    }

    private var braceletStatusLabel: String {
        profile.braceletLinked ? "Linked bracelet ›" : "Not linked — tap to pair ›"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header — matches Main.dc.html (no wordmark nav bar)
                header

                // YOU card (no section label in Main design)
                cardGroup {
                    profileRow(label: "Name", value: profile.name)
                    thinDivider
                    profileRow(label: "Birth date", value: profile.birthDate)
                    thinDivider
                    profileRow(label: "Blood type", value: profile.bloodType)
                }
                .padding(.top, 2)

                listSection(title: "Allergies", items: profile.allergies)
                listSection(title: "Medications", items: profile.medications)
                listSection(title: "Conditions", items: profile.conditions)

                // CONTACTS
                SectionLabel(text: "Contacts").padding(.horizontal, 16).padding(.top, 12)
                cardGroup {
                    if profile.contacts.isEmpty {
                        emptyRow()
                    } else {
                        ForEach(Array(profile.contacts.enumerated()), id: \.element.id) { i, c in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.redmedDark)
                                Text(c.detail)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.redmedMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            if i < profile.contacts.count - 1 { thinDivider }
                        }
                    }
                }

                // QUICK ACTIONS
                HStack(spacing: 10) {
                    Button { tab = .nfc } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.redmedAccent)
                            Text("Bracelet")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.redmedAccent)
                                .kerning(-0.1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(Color.redmedDark.opacity(0.12))
                        .frame(width: 0.5, height: 18)

                    Button { showHelp = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.redmedMuted)
                            Text("How it works")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.redmedMuted)
                                .kerning(-0.1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 42)
                .padding(.bottom, 4)

                Text("\"Control your fear. Control the moment.\nYou have what it takes to save a life.\"")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.redmedDark)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 33)
                    .padding(.bottom, 16)
            }
            .padding(.bottom, 12)
        }
        .background(Color.redmedBg)
        .fullScreenCover(isPresented: $showEdit) {
            EditProfileView().environmentObject(profile)
        }
        .sheet(isPresented: $showHelp) {
            HelpMenuView()
        }
        .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to edit your medical profile.")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                if !profile.hasData {
                    (
                        Text("Tap ").font(.system(size: 11, weight: .medium)).foregroundColor(.redmedMuted)
                        + Text("Edit").font(.system(size: 11, weight: .bold)).foregroundColor(.redmedAccent)
                        + Text(" to add your name and set up your bracelet.")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.redmedMuted)
                    )
                    .lineSpacing(2)
                    .padding(.bottom, 4)
                }

                Button { tab = .nfc } label: {
                    HStack(spacing: 8) {
                        Image("BrandLogo")
                            .resizable()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                            .shadow(color: Color.redmedAccent.opacity(0.15), radius: 5, y: 3)
                            .opacity(profile.hasData ? 1 : 0.5)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(deviceName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.redmedDark)
                                .kerning(-0.4)
                                .lineLimit(1)

                            Text(braceletStatusLabel)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(
                                    profile.braceletLinked
                                        ? Color.redmedAccent.opacity(0.85)
                                        : .redmedMuted
                                )
                                .kerning(0.7)
                                .textCase(.uppercase)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 56)

            Button("Edit") { requestEdit() }
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.redmedAccent)
                .kerning(-0.2)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Edit gate

    private func requestEdit() {
        // Gate on any saved medical fields — not just name — so clearing the
        // name cannot bypass Face ID while allergies/meds/etc. remain.
        guard profile.hasSensitiveProfileData else {
            showEdit = true
            return
        }
        BiometricAuth.authenticate(reason: "Authenticate to edit your medical profile.") { success in
            if success {
                showEdit = true
            } else {
                showAuthFailedAlert = true
            }
        }
    }

    // MARK: - Rows / cards

    private var thinDivider: some View {
        Divider().overlay(Color.redmedDivider)
    }

    @ViewBuilder
    func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.redmedMuted)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 11, weight: value.isEmpty ? .regular : .semibold))
                .foregroundColor(value.isEmpty ? Color.redmedMuted.opacity(0.4) : .redmedDark)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    func emptyRow() -> some View {
        Text("—")
            .font(.system(size: 11))
            .foregroundColor(Color.redmedMuted.opacity(0.4))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
    }

    @ViewBuilder
    func cardGroup<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.redmedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.redmedDark.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    func listSection(title: String, items: [String]) -> some View {
        SectionLabel(text: title).padding(.horizontal, 16).padding(.top, 12)
        cardGroup {
            if items.isEmpty {
                emptyRow()
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Text(item)
                        .font(.system(size: 11))
                        .foregroundColor(.redmedDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                    if i < items.count - 1 { thinDivider }
                }
            }
        }
    }
}
