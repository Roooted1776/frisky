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
    @State private var openAllergies = true
    @State private var openMedications = true
    @State private var openConditions = true

    private var deviceName: String {
        // Filled name replaces the grey logo on the left (owner + tap / Preview).
        if !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return profile.name
        }
        if isScannerSession { return "RedMed" }
        return "Your iPhone"
    }

    private var hasImportedName: Bool {
        !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    // YOU card — Name: empty keeps grey label; filled name replaces it (owner + tap).
                    cardGroup {
                        nameProfileRow
                        thinDivider
                        profileRow(label: "Birth date", value: profile.birthDate, emptyPrompt: "Add birth date")
                        thinDivider
                        profileRow(label: "Blood type", value: profile.bloodType, emptyPrompt: "Add blood type")
                    }
                    .padding(.top, 2)

                    listDropdown(title: "Allergies", items: profile.allergies, emptyPrompt: "Add allergy", open: $openAllergies)
                    listDropdown(title: "Medications", items: profile.medications, emptyPrompt: "Add medication", open: $openMedications)
                    listDropdown(title: "Conditions", items: profile.conditions, emptyPrompt: "Add condition", open: $openConditions)

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
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if !c.phone.isEmpty {
                                            Text(c.phone)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.redmedDark)
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
                        // QUICK ACTIONS (owner only) — Bracelet / Help / Preview
                        HStack(spacing: 10) {
                            Button { tab = .nfc } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.redmedAccent)
                                    Text("Bracelet")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.redmedAccent)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.redmedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                                        .strokeBorder(Color.redmedDivider, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Button { showHelp = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.redmedMuted)
                                    Text("Help")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.redmedMuted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.redmedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                                        .strokeBorder(Color.redmedDivider, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            if profile.hasData {
                                Button {
                                    guard PasserbyHTMLCardView.payload(from: profile) != nil else { return }
                                    showScannerPreview = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "eye")
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundColor(.redmedMuted)
                                        Text("Preview")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.redmedMuted)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.redmedSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                                            .strokeBorder(Color.redmedDivider, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                        .padding(.bottom, 8)
                    }

                    // Whisper prayer — same on owner + tapper main RedMed (and Aid).
                    Text("\"Control your fear. Control the moment.\nYou have what it takes to save a life.\"")
                        .font(.system(size: 8, weight: .regular))
                        .italic()
                        .foregroundColor(.redmedMuted.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.top, isScannerSession ? 28 : 16)
                        .padding(.bottom, 8)
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
        }
        .fullScreenCover(isPresented: Binding(
            get: { showScannerPreview && !isScannerSession && profile.hasData },
            set: { showScannerPreview = $0 && !isScannerSession }
        )) {
            PasserbyHTMLCardView(
                payloadOrURL: PasserbyHTMLCardView.payload(from: profile) ?? ""
            )
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 275)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .redmedBox()
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                } else if !profile.hasData {
                    (
                        Text("Tap ").font(.system(size: 12, weight: .medium)).foregroundColor(.redmedMuted)
                        + Text("Edit").font(.system(size: 12, weight: .bold)).foregroundColor(.redmedAccent)
                        + Text(" to add your name and set up your bracelet.")
                            .font(.system(size: 12, weight: .medium)).foregroundColor(.redmedMuted)
                    )
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 275)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .redmedBox()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
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
                // Same slot + chrome as owner Edit (main page).
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
            // Empty: grey logo on the left. Filled: logo drops; imported name takes the row.
            if !hasImportedName {
                Image("BrandLogo")
                    .resizable()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.logoRadius))
                    .shadow(color: Color.redmedAccent.opacity(0.15), radius: 5, y: 3)
                    .opacity(0.72)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(deviceName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                    .kerning(-0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

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
            .frame(maxWidth: .infinity, alignment: .leading)
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
        ) { outcome in
            if outcome == .success {
                requireAuthOnSave = false
                showEdit = true
            } else if outcome == .notVerified {
                showAuthFailedAlert = true
            }
        }
    }

    // MARK: - Rows / cards

    private var thinDivider: some View {
        Divider().overlay(Color.redmedDivider)
    }

    /// Empty: muted "Name" + prompt. Filled: grey label drops; imported name sits left.
    @ViewBuilder
    private var nameProfileRow: some View {
        Button {
            if !hasImportedName && !isScannerSession { requestEdit() }
        } label: {
            HStack(spacing: 8) {
                if !hasImportedName {
                    Text("Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.redmedMuted)
                    Text(isScannerSession ? "—" : "Add name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isScannerSession ? Color.redmedDark.opacity(0.55) : .redmedAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(profile.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(hasImportedName || isScannerSession)
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
                        .foregroundColor(isScannerSession ? Color.redmedDark.opacity(0.55) : .redmedAccent)
                } else {
                    Text(value)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
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
            .redmedBox()
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    func listDropdown(title: String, items: [String], emptyPrompt: String, open: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { open.wrappedValue.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.redmedAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !items.isEmpty {
                        Text("\(items.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.redmedAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.redmedAccent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                    }
                    Image(systemName: open.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityHint(open.wrappedValue ? "Collapse" : "Expand")

            if open.wrappedValue {
                VStack(spacing: 0) {
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
                .overlay(alignment: .top) {
                    Divider().overlay(Color.redmedDivider)
                }
            }
        }
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
        .overlay(
            RoundedRectangle(cornerRadius: RedMedChrome.boxRadius)
                .strokeBorder(
                    open.wrappedValue ? Color.redmedAccent.opacity(0.35) : Color.redmedDivider,
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
