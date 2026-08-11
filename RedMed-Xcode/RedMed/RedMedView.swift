import SwiftUI

struct RedMedView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @Binding var tab: AppTab
    @State private var showEdit = false
    /// When true, Edit opened without Face ID (empty RedMed profile) — Save must authenticate.
    @State private var requireAuthOnSave = false
    @State private var showHelp = false
    @State private var showScannerPreview = false
    @State private var showAuthFailedAlert = false

    private var deviceName: String {
        if isScannerSession {
            return profile.name.isEmpty ? "RedMed" : profile.name
        }
        if profile.name.isEmpty { return "Your iPhone" }
        return "\(profile.name)'s iPhone"
    }

    private var braceletStatusLabel: String {
        // One RedMed header for owner + responder. Linked only after NFC write
        // and YOU-card identity (name, birth, blood) is filled.
        if profile.showsBraceletAsLinked {
            return isScannerSession ? "Linked bracelet" : "Linked bracelet ›"
        }
        return isScannerSession ? "Not linked" : "Not linked — tap to pair ›"
    }

    var body: some View {
        ScrollView {
            // Header outside LazyVStack so band pairing flips immediately when NFC write / edit lands.
            VStack(alignment: .leading, spacing: 0) {
                header

                LazyVStack(alignment: .leading, spacing: 0) {
                    // YOU card (no section label in Main design)
                    cardGroup {
                        nameProfileRow
                        thinDivider
                        profileRow(label: "Birth date", value: profile.birthDate, emptyPrompt: "Add birth date")
                        thinDivider
                        profileRow(label: "Blood type", value: profile.bloodType, emptyPrompt: "Add blood type")
                    }
                    .padding(.top, 2)

                    listSection(title: "Allergies", items: profile.allergies, emptyPrompt: "Add allergy")
                    listSection(title: "Medications", items: profile.medications, emptyPrompt: "Add medication")
                    listSection(title: "Conditions", items: profile.conditions, emptyPrompt: "Add condition")

                    // CONTACTS
                    SectionLabel(text: "Contacts").padding(.horizontal, 16).padding(.top, 12)
                    cardGroup {
                        if profile.contacts.isEmpty {
                            emptyPromptRow("Add contact")
                        } else {
                            ForEach(Array(profile.contacts.enumerated()), id: \.element.id) { i, c in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(c.name.isEmpty ? "Emergency contact" : c.name)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.redmedDark)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if !c.phone.isEmpty {
                                            Text(c.phone)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.redmedAccent)
                                                .multilineTextAlignment(.trailing)
                                        }
                                    }
                                    if !c.relationship.isEmpty {
                                        Text(c.relationship)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.redmedMuted)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                if i < profile.contacts.count - 1 { thinDivider }
                            }
                        }
                    }

                    if !isScannerSession {
                        // QUICK ACTIONS (owner only) — full app: Bracelet / How it works / Preview scanner
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

                            if profile.hasData {
                                Button { showScannerPreview = true } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "eye")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.redmedMuted)
                                        Text("Preview scanner")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.redmedMuted)
                                            .kerning(-0.1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 42)
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(.bottom, isScannerSession ? 42 : 12)
        }
        // Owner profile only — never redact the passerby / EMS scanner card.
        .privacySensitive(!isScannerSession)
        .background(Color.redmedBg)
        .fullScreenCover(isPresented: Binding(
            get: { showEdit && !isScannerSession },
            set: { showEdit = $0 && !isScannerSession }
        )) {
            EditProfileView(requireAuthOnSave: requireAuthOnSave)
                .environmentObject(profile)
        }
        .sheet(isPresented: Binding(
            get: { showHelp && !isScannerSession },
            set: { showHelp = $0 && !isScannerSession }
        )) {
            HelpMenuView(onOpenNFC: { tab = .nfc })
                .environmentObject(profile)
        }
        .fullScreenCover(isPresented: Binding(
            get: { showScannerPreview && !isScannerSession && profile.hasData },
            set: { showScannerPreview = $0 && !isScannerSession }
        )) {
            PublicCardView(profile: profile)
        }
        .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to edit your RedMed profile.")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                if isScannerSession {
                    Text("Read only — editing needs the owner’s RedMed app.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .lineSpacing(2)
                        .padding(.bottom, 4)
                } else if !profile.hasData {
                    (
                        Text("Tap ").font(.system(size: 11, weight: .medium)).foregroundColor(.redmedMuted)
                        + Text("Edit").font(.system(size: 11, weight: .bold)).foregroundColor(.redmedAccent)
                        + Text(" to add your name and set up your bracelet.")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.redmedMuted)
                    )
                    .lineSpacing(2)
                    .padding(.bottom, 4)
                }

                // Same title + bracelet line for owner and responder (scanner).
                Group {
                    if isScannerSession {
                        titleRow
                    } else {
                        Button { tab = .nfc } label: { titleRow }
                            .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 56)

            if isScannerSession {
                ScannerBackButton()
                    .padding(.top, 4)
            } else {
                ChromeTextAction(title: "Edit") { requestEdit() }
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var titleRow: some View {
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
                        profile.showsBraceletAsLinked
                            ? Color.redmedAccent.opacity(0.85)
                            : .redmedMuted
                    )
                    .kerning(0.7)
                    .textCase(.uppercase)
                    .id(profile.showsBraceletAsLinked)
                    .animation(.easeInOut(duration: 0.2), value: profile.showsBraceletAsLinked)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Edit gate

    private func requestEdit() {
        // Scanners never edit — UI gate alone is not enough.
        guard !isScannerSession else { return }
        guard profile.hasSensitiveProfileData else {
            // First fill: open freely, Face ID on Save (see EditProfileView.requireAuthOnSave).
            requireAuthOnSave = true
            showEdit = true
            return
        }
        BiometricAuth.authenticate(
            reason: "Unlock with Face ID, Touch ID, or passcode to edit your RedMed profile."
        ) { success in
            if success {
                requireAuthOnSave = false
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

    /// Name value sits left (after label), bold — same 11pt system as other YOU fields.
    @ViewBuilder
    private var nameProfileRow: some View {
        Button {
            if profile.name.isEmpty && !isScannerSession { requestEdit() }
        } label: {
            HStack(spacing: 8) {
                Text("Name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.redmedMuted)
                if profile.name.isEmpty {
                    Text(isScannerSession ? "—" : "Add name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isScannerSession ? Color.redmedMuted.opacity(0.4) : .redmedAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(profile.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.redmedDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!profile.name.isEmpty || isScannerSession)
    }

    @ViewBuilder
    func profileRow(label: String, value: String, emptyPrompt: String) -> some View {
        Button {
            if value.isEmpty && !isScannerSession { requestEdit() }
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.redmedMuted)
                Spacer()
                if value.isEmpty {
                    Text(isScannerSession ? "—" : emptyPrompt)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isScannerSession ? Color.redmedMuted.opacity(0.4) : .redmedAccent)
                } else {
                    Text(value)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.redmedDark)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!value.isEmpty || isScannerSession)
    }

    @ViewBuilder
    func emptyPromptRow(_ prompt: String) -> some View {
        Button {
            if !isScannerSession { requestEdit() }
        } label: {
            Text(isScannerSession ? "—" : prompt)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isScannerSession ? Color.redmedMuted.opacity(0.4) : .redmedAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isScannerSession)
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
    func listSection(title: String, items: [String], emptyPrompt: String) -> some View {
        SectionLabel(text: title).padding(.horizontal, 16).padding(.top, 12)
        cardGroup {
            if items.isEmpty {
                emptyPromptRow(emptyPrompt)
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
