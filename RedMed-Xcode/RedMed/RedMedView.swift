import SwiftUI

/// Owner / scanner RedMed tab — native YOU card (header + identity + lists).
/// Bundled `tapper.html` is passerby + NFC Preview / Scan only. No WKWebView
/// on this tab: WebKit parse was the cold-open stall, and a parked embed
/// under 911 / Aid / NFC kept the compositor hot mid-session.
/// Owner chrome: logo + name + Linked with Edit trailing (no Help dock).
/// Scanners keep Back. Help lives on 911 / Aid / NFC — not on Edit.
/// Fresh install: native setup funnel. Passerby tapper is unchanged.
struct RedMedView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @State private var showEdit = false
    @State private var healthImportBusy = false
    @State private var healthImportMessage: String?
    /// HealthKit characteristics to seed Edit. Not written to ProfileData until Save.
    @State private var healthSeed: HealthKitProfileImport.Draft?

    /// Owner empty profile — native steps instead of a blank YOU card.
    /// Hidden while a stored ID is expected or restore is in flight.
    private var showsOwnerSetupFunnel: Bool {
        !isScannerSession
            && !profile.hasSensitiveProfileData
            && !profile.isRestoringFromKeychain
            && !ProfileData.prefersLockOnLaunch
            && !ProfileData.hasStoredProfile()
    }

    var body: some View {
        VStack(spacing: 0) {
            if isScannerSession {
                HStack(alignment: .center, spacing: 12) {
                    ScannerBackButton()
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .redmedTopChromeFill()
            } else {
                RedMedUserHeader(
                    name: profile.name,
                    linked: profile.showsBraceletAsLinked,
                    onEdit: { requestEdit() },
                    onStatus: {
                        NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                    }
                )
            }

            Group {
                if showsOwnerSetupFunnel {
                    OwnerSetupFunnel(
                        healthBusy: healthImportBusy,
                        healthMessage: healthImportMessage,
                        onFill: { requestEdit() },
                        onHealthImport: { Task { await importFromHealthThenEdit() } }
                    )
                } else {
                    VStack(spacing: 0) {
                        if !isScannerSession {
                            ownerNextStepBanner
                        }
                        OwnerYouCard()
                            .id(profile.cardEpoch)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Big bottom "Help" dock removed from the RedMed user page.
            // Help remains available via other native chrome on the
            // 911 / Aid / NFC tabs (not the Edit modal bar).
        }
        // Owner profile only — never redact the passerby / EMS scanner card.
        .privacySensitive(!isScannerSession)
        .background { RedMedPageBackground() }
        .fullScreenCover(isPresented: Binding(
            get: { showEdit && !isScannerSession },
            set: { showEdit = $0 && !isScannerSession }
        )) {
            EditProfileView(healthSeed: healthSeed)
                .environmentObject(profile)
                .presentationBackground(Color.redmedBg)
        }
    }

    /// Sibling above the YOU card — never an overlay on the tap card.
    @ViewBuilder
    private var ownerNextStepBanner: some View {
        if profile.isRestoringFromKeychain {
            EmptyView()
        } else if !profile.isEmergencyProfileConfigured {
            OwnerNextStepBanner(
                icon: "square.and.pencil",
                title: "Finish Your Medical ID",
                detail: "Add birth date and blood type so helpers see a complete ID.",
                actionTitle: "Edit",
                action: { requestEdit() }
            )
        } else if !profile.showsBraceletAsLinked {
            OwnerNextStepBanner(
                icon: "wave.3.right",
                title: AppConfig.nfcHardwareEnabled ? "Write Your Band" : "Preview The Helper Card",
                detail: AppConfig.nfcHardwareEnabled
                    ? "Write the band on the NFC tab so a passerby tap opens this card."
                    : "Band write is preview-only in this build. Open NFC to see what helpers would see.",
                actionTitle: "NFC",
                action: {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            )
        }
    }

    // MARK: - Edit gate

    private func requestEdit() {
        // Scanners never edit. Face ID is on Save only, not on opening Edit.
        guard !isScannerSession else { return }
        showEdit = true
    }

    /// Optional Health fill on the empty funnel, then Edit so Save still Face ID gates persist.
    @MainActor
    private func importFromHealthThenEdit() async {
        guard !isScannerSession, !healthImportBusy else { return }
        healthImportBusy = true
        healthImportMessage = nil
        defer { healthImportBusy = false }
        do {
            let draft = try await HealthKitProfileImport.readCharacteristics()
            healthSeed = draft
            healthImportMessage = draft.filledCount == 2
                ? "Birth date and blood type ready. Add your name, then Save."
                : "Copied from Apple Health. Add your name, then Save."
            showEdit = true
        } catch {
            healthImportMessage = error.localizedDescription
        }
    }
}

// MARK: - Tapper header (owner RedMed)

/// Same YOU-card header as passerby `tapper.html` `.rm-header` — logo, name,
/// Linked / Not linked — with Edit as trailing chrome. Scanner Preview keeps
/// the HTML header.
private struct RedMedUserHeader: View {
    let name: String
    let linked: Bool
    var onEdit: () -> Void
    var onStatus: () -> Void

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "RedMed" : trimmed
    }

    private var statusTitle: String {
        linked ? "Linked Bracelet" : "Not Linked"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("BrandLogo")
                .resizable()
                .scaledToFill()
                .frame(width: RedMedChrome.logoSize, height: RedMedChrome.logoSize)
                .clipShape(Circle())
                .shadow(color: Color.redmedAccent.opacity(0.18), radius: 10, y: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.5)
                    .foregroundColor(.redmedDark)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onStatus) {
                    HStack(spacing: 2) {
                        Text(statusTitle)
                            .font(.system(size: 12, weight: .bold))
                            .kerning(0.5)
                            .textCase(.uppercase)
                        Text("›")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.redmedAccent)
                }
                .buttonStyle(RedMedPressStyle(scale: 0.98, haptic: nil))
                .accessibilityLabel(statusTitle)
                .accessibilityHint("Opens NFC")
            }

            Spacer(minLength: 8)

            ChromeTextAction(title: "Edit", action: onEdit)
        }
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .redmedTopChromeWash()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Native YOU card

/// Same fields as passerby `tapper.html` (identity rows + list drops). SwiftUI
/// only — no WebKit. Empty lists stay hidden. Contacts dial `tel:` like the HTML card.
private struct OwnerYouCard: View {
    @EnvironmentObject var profile: ProfileData

    private var trimmedName: String {
        profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasLists: Bool {
        !profile.allergies.isEmpty
            || !profile.medications.isEmpty
            || !profile.conditions.isEmpty
            || profile.contacts.contains {
                !$0.name.isEmpty || !$0.relationship.isEmpty || !$0.phone.isEmpty
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                identityCard
                if hasLists {
                    listsCard
                }
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var identityCard: some View {
        VStack(spacing: 0) {
            youRow(label: "Name", value: trimmedName)
            Divider().overlay(Color.redmedDivider)
            youRow(label: "Birth Date", value: YouCardFormat.birthDate(profile.birthDate))
            Divider().overlay(Color.redmedDivider)
            youRow(label: "Blood Type", value: profile.bloodType.trimmingCharacters(in: .whitespacesAndNewlines))
            Divider().overlay(Color.redmedDivider)
            youRow(label: "Organ Donor", value: profile.isOrganDonor ? "Yes" : "")
            Divider().overlay(Color.redmedDivider)
            youRow(label: "Pregnant", value: profile.isPregnant ? "Yes" : "")
            Divider().overlay(Color.redmedDivider)
            youRow(label: "Deaf / Vision Impaired", value: profile.isDeafOrVisionImpaired ? "Yes" : "")
        }
        // flatten: false — compositingGroup kept the empty "—" paint after
        // Keychain restore (same reason Edit uses flatten: false).
        .redmedBox(flatten: false)
    }

    private func youRow(label: String, value: String) -> some View {
        let shown = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
            Spacer(minLength: 12)
            Text(shown.isEmpty ? "—" : shown)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(shown.isEmpty ? Color.redmedDark.opacity(0.4) : .redmedDark)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(shown.isEmpty ? "Empty" : shown)
    }

    private var listsCard: some View {
        VStack(spacing: 0) {
            YouListDrop(title: "Allergies", items: profile.allergies)
            YouListDrop(title: "Medications", items: profile.medications)
            YouListDrop(title: "Conditions", items: profile.conditions)
            YouContactDrop(contacts: profile.contacts)
        }
        .redmedBox(flatten: false)
    }
}

private enum YouCardFormat {
    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static func birthDate(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        if let date = iso.date(from: s) { return display.string(from: date) }
        return s
    }
}

private struct YouListDrop: View {
    let title: String
    let items: [String]
    @State private var open = true

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    var t = Transaction()
                    t.animation = nil
                    withTransaction(t) { open.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedDark)
                        Text("\(items.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.redmedMuted)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.redmedMuted)
                            .rotationEffect(.degrees(open ? 90 : 0))
                    }
                    .padding(.horizontal, RedMedChrome.pagePadX)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RedMedPressStyle(scale: 0.99, haptic: nil))
                .accessibilityLabel(title)
                .accessibilityValue("\(items.count)")
                .accessibilityHint(open ? "Collapse" : "Expand")

                if open {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        Text(item)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.redmedDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, RedMedChrome.pagePadX)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
    }
}

private struct YouContactDrop: View {
    let contacts: [EmergencyContact]
    @State private var open = true

    private var filled: [EmergencyContact] {
        contacts.filter {
            !$0.name.isEmpty || !$0.relationship.isEmpty || !$0.phone.isEmpty
        }
    }

    var body: some View {
        if filled.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    var t = Transaction()
                    t.animation = nil
                    withTransaction(t) { open.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text("Contacts")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedDark)
                        Text("\(filled.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.redmedMuted)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.redmedMuted)
                            .rotationEffect(.degrees(open ? 90 : 0))
                    }
                    .padding(.horizontal, RedMedChrome.pagePadX)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RedMedPressStyle(scale: 0.99, haptic: nil))
                .accessibilityLabel("Contacts")
                .accessibilityValue("\(filled.count)")

                if open {
                    ForEach(filled) { contact in
                        contactRow(contact)
                    }
                }
            }
        }
    }

    private func contactRow(_ contact: EmergencyContact) -> some View {
        let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shownName = name.isEmpty ? "Emergency Contact" : name
        let digits = contact.dialDigits
        let phoneShown: String = {
            if digits.isEmpty { return "" }
            let parsed = CountryDialCode.parse(contact.phone)
            if parsed.country.dialCode == "+1" {
                return CountryDialCode.formattedNANP(digits: parsed.localNumber)
            }
            return contact.phone
        }()
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(shownName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedDark)
                Spacer(minLength: 8)
                if !digits.isEmpty, let url = URL(string: "tel:\(digits == "911" ? "911" : digits)") {
                    Link(phoneShown, destination: url)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                }
            }
            if !contact.relationship.isEmpty {
                Text(contact.relationship)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.redmedMuted)
            }
        }
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - First-fill funnel (owner empty profile)

/// Native setup on the owner RedMed tab. Replaces the empty YOU card — not an overlay
/// on a live tap card. Scanners never see this.
private struct OwnerSetupFunnel: View {
    var healthBusy: Bool
    var healthMessage: String?
    var onFill: () -> Void
    var onHealthImport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ghostYouCard
                stepsCard
                PrimaryButton(title: "Fill Medical ID", action: onFill)
                if HealthKitProfileImport.isAvailable {
                    healthButton
                    Text("Birth date and blood type only. RedMed never writes back to Health.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                }
                if let healthMessage, !healthMessage.isEmpty {
                    Text(healthMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Same YOU-card chrome as tapper — empty slots plus the fill CTA below.
    private var ghostYouCard: some View {
        VStack(spacing: 0) {
            ghostRow(label: "Name", value: "—")
            Divider().overlay(Color.redmedDivider)
            ghostRow(label: "Birth Date", value: "—")
            Divider().overlay(Color.redmedDivider)
            ghostRow(label: "Blood Type", value: "—")
            Divider().overlay(Color.redmedDivider)
            ghostRow(label: "Organ Donor", value: "—")
            Divider().overlay(Color.redmedDivider)
            ghostRow(label: "Pregnant", value: "—")
            Divider().overlay(Color.redmedDivider)
            ghostRow(label: "Deaf / Vision Impaired", value: "—")
        }
        .redmedBox()
        .accessibilityHidden(true)
    }

    private func ghostRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.redmedDark.opacity(0.4))
        }
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.vertical, 11)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Get Started")
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 2)
            stepRow(number: "1", title: "Fill Your Medical ID", detail: "Name, birth date, blood type. Allergies and contacts help EMS.")
            Divider().overlay(Color.redmedDivider).padding(.leading, 54)
            stepRow(number: "2", title: "Save", detail: "Face ID writes it to this iPhone's Keychain. Nothing leaves the phone.")
            Divider().overlay(Color.redmedDivider).padding(.leading, 54)
            stepRow(number: "3", title: AppConfig.nfcHardwareEnabled ? "Write The Band" : "Preview The Helper Card", detail: AppConfig.nfcHardwareEnabled ? "NFC tab packs the card onto the chip. Helpers tap. No app, no login." : "NFC tab packs the card for Preview. Live band write ships when NFC Tag Reading is on the App ID.")
        }
        .redmedBox()
    }

    private var healthButton: some View {
        OutlineButton(
            title: healthBusy ? "Reading Apple Health…" : "Fill From Apple Health",
            systemImage: healthBusy ? nil : "heart.text.square",
            busy: healthBusy
        ) {
            onHealthImport()
        }
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.redmedAccent.opacity(0.12))
                Text(number)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.redmedAccent)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.redmedDark)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

/// Compact next-step chip above the YOU card.
private struct OwnerNextStepBanner: View {
    let icon: String
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 28, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.redmedDark)
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                HStack(spacing: 2) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .bold))
                    Text("›")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.redmedAccent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(RedMedPressStyle(scale: 0.98))
        .redmedBox()
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.bottom, 8)
        .accessibilityHint("Opens \(actionTitle)")
    }
}
