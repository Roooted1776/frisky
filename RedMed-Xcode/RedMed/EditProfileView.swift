import SwiftUI
import UIKit

struct EditProfileView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.dismiss) var dismiss
    @Environment(\.isScannerSession) private var isScannerSession

    /// True when Edit opened without Face ID (first fill). Save then requires biometrics.
    var requireAuthOnSave: Bool = false
    /// Optional Apple Health seed (birth date / blood type). Applied to empty draft fields only.
    var healthSeed: HealthKitProfileImport.Draft? = nil

    @State private var youFullName = ""
    @State private var birthDate = ""
    @State private var bloodType = ""
    @State private var isOrganDonor = false
    @State private var allergies: [DraftLine] = []
    @State private var medications: [DraftLine] = []
    @State private var conditions: [DraftLine] = []
    @State private var contacts: [EmergencyContact] = []
    @State private var showAuthFailedAlert = false
    @State private var showSaveFailedAlert = false
    @State private var showBirthDatePicker = false
    @State private var showBloodTypePicker = false
    @State private var pickerBirthDate = EditProfileView.defaultBirthDate
    /// Active allergy/med/condition row for the bottom suggestion strip.
    /// No FocusState — sheet-wide focus tracking hung Edit between sections.
    @State private var suggestionLineID: UUID?
    @State private var suggestionMatches: [String] = []
    @State private var healthImportBusy = false
    @State private var healthImportMessage: String?

    private static let bloodTypeChoices = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]

    /// One body size across the edit form (labels, fields, prompts).
    /// Nav bar metrics live in `RedMedChrome` so Help / Edit stay even.
    private enum Metrics {
        static let font: CGFloat = 15
        static let icon: CGFloat = 18
        static let labelWidth: CGFloat = 100
        static let rowHPad: CGFloat = RedMedChrome.pagePadX
        static let rowVPad: CGFloat = 13
        static let sectionGap: CGFloat = 22
    }

    private static let birthDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    private static let birthDateParsers: [DateFormatter] = {
        ["MMMM d, yyyy", "MMM d, yyyy", "M/d/yyyy", "MM/dd/yyyy", "yyyy-MM-dd"].map { format in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            return f
        }
    }()

    private static var birthDateRange: ClosedRange<Date> {
        let start = Calendar.current.date(byAdding: .year, value: -120, to: Date()) ?? Date.distantPast
        return start...Date()
    }

    private static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    }

    private var hasBirthDate: Bool { Self.parseBirthDate(birthDate) != nil }

    var body: some View {
        if isScannerSession {
            Color.clear.onAppear { dismiss() }
        } else {
            editorBody
                .onAppear { profile.holdsEditingSession = true }
                .onDisappear { profile.holdsEditingSession = false }
        }
    }

    private var editorBody: some View {
        VStack(spacing: 0) {
            OwnerModalActionBar(
                leadingTitle: "Cancel",
                leadingAction: {
                    Self.dismissKeyboard()
                    dismiss()
                },
                trailingTitle: "Save",
                trailingAction: save
            ) {
                EmptyView()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    editSectionLabel("You")
                    editCard {
                        youRow(label: "Name") {
                            // Own view + stable id — list TextFields in this sheet
                            // were stealing the first field's UIKit coordinator (name).
                            YouNameField(text: $youFullName)
                                .id("edit-you-full-name")
                        }
                        Divider().padding(.leading, Metrics.labelWidth + 12 + Metrics.rowHPad)
                        birthDateRow
                        Divider().padding(.leading, Metrics.labelWidth + 12 + Metrics.rowHPad)
                        bloodTypeRow
                        Divider().padding(.leading, Metrics.labelWidth + 12 + Metrics.rowHPad)
                        Toggle(isOn: $isOrganDonor) {
                            Text("Organ donor")
                                .font(.system(size: Metrics.font, weight: .medium))
                                .foregroundColor(.redmedMuted)
                        }
                        .tint(.redmedAccent)
                        .padding(.horizontal, Metrics.rowHPad)
                        .padding(.vertical, Metrics.rowVPad)
                    }

                    if HealthKitProfileImport.isAvailable {
                        healthImportCard
                    }

                    editSectionLabel("Allergies")
                    editCard {
                        DraftLinesEditor(
                            lines: $allergies,
                            sectionKey: "allergies",
                            placeholder: "Allergy",
                            addLabel: "Add allergy",
                            onTextChange: { id, text in
                                refreshSuggestions(lineID: id, text: text, lines: allergies, catalog: SuggestionCatalog.allergies)
                            }
                        )
                    }

                    editSectionLabel("Medications")
                    editCard {
                        DraftLinesEditor(
                            lines: $medications,
                            sectionKey: "medications",
                            placeholder: "Medication",
                            addLabel: "Add medication",
                            onTextChange: { id, text in
                                refreshSuggestions(lineID: id, text: text, lines: medications, catalog: SuggestionCatalog.medications)
                            }
                        )
                    }

                    editSectionLabel("Conditions")
                    editCard {
                        DraftLinesEditor(
                            lines: $conditions,
                            sectionKey: "conditions",
                            placeholder: "Condition",
                            addLabel: "Add condition",
                            onTextChange: { id, text in
                                refreshSuggestions(lineID: id, text: text, lines: conditions, catalog: SuggestionCatalog.conditions)
                            }
                        )
                    }

                    editSectionLabel("Emergency Contacts")
                    editCard {
                        contactsEditor
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, Metrics.rowHPad)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.visible)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                suggestionStrip
            }
        }
        .background { RedMedPageBackground() }
        // Once on the sheet — per-field `.privacySensitive()` made SwiftUI
        // reuse the first TextField coordinator (list typing landed in Name).
        .privacySensitive()
        .onAppear {
            loadDraft()
            SuggestionCatalog.warmUp()
        }
        .alert(BiometricAuth.deniedAlertTitle, isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(BiometricAuth.deniedAlertMessage(action: "save"))
        }
        .alert("Couldn't Save", isPresented: $showSaveFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your profile could not be written to the secure on-device Keychain. Try again.")
        }
        .sheet(isPresented: $showBirthDatePicker) {
            birthDatePickerSheet
                .presentationBackground(Color.redmedBg)
        }
        .confirmationDialog("Blood type", isPresented: $showBloodTypePicker, titleVisibility: .visible) {
            ForEach(Self.bloodTypeChoices, id: \.self) { type in
                Button(type) { bloodType = type }
            }
            if !bloodType.isEmpty {
                Button("Clear", role: .destructive) { bloodType = "" }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Suggestion strip (no FocusState — keyed off text changes only)

    @ViewBuilder
    private var suggestionStrip: some View {
        if !suggestionMatches.isEmpty {
            VStack(spacing: 0) {
                Divider().overlay(Color.redmedDivider)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestionMatches, id: \.self) { suggestion in
                            Button {
                                applySuggestion(suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 14))
                                    .foregroundColor(.redmedDark)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.redmedAccent.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metrics.rowHPad)
                    .padding(.vertical, 10)
                }
                .background(Color.redmedBg)
            }
        }
    }

    private func refreshSuggestions(
        lineID: UUID,
        text: String,
        lines: [DraftLine],
        catalog: [SuggestionCatalog.Entry]
    ) {
        if suggestionLineID != lineID {
            suggestionLineID = lineID
        }
        let taken = Set(
            lines.lazy
                .filter { $0.id != lineID }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        let next = SuggestionCatalog.matches(query: text, in: catalog, excludingTaken: taken)
        if next != suggestionMatches {
            suggestionMatches = next
        }
    }

    private func applySuggestion(_ suggestion: String) {
        guard let id = suggestionLineID else { return }
        if let i = allergies.firstIndex(where: { $0.id == id }) {
            allergies[i].text = suggestion
        } else if let i = medications.firstIndex(where: { $0.id == id }) {
            medications[i].text = suggestion
        } else if let i = conditions.firstIndex(where: { $0.id == id }) {
            conditions[i].text = suggestion
        }
        suggestionMatches = []
    }

    // MARK: - You

    private func youRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: Metrics.font, weight: .medium))
                .foregroundColor(.redmedMuted)
                .frame(width: Metrics.labelWidth, alignment: .leading)
                .padding(.trailing, 12)
            content()
        }
        .padding(.horizontal, Metrics.rowHPad)
        .padding(.vertical, Metrics.rowVPad)
    }

    private var birthDateRow: some View {
        HStack(spacing: 0) {
            Text("Birth date")
                .font(.system(size: Metrics.font, weight: .medium))
                .foregroundColor(.redmedMuted)
                .frame(width: Metrics.labelWidth, alignment: .leading)
                .padding(.trailing, 12)

            Button {
                pickerBirthDate = Self.parseBirthDate(birthDate) ?? Self.defaultBirthDate
                showBirthDatePicker = true
            } label: {
                Text(hasBirthDate ? birthDate : "Select date")
                    .font(.system(size: Metrics.font, weight: .medium))
                    .foregroundColor(hasBirthDate ? .redmedDark : .redmedAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hasBirthDate {
                Button {
                    birthDate = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Metrics.icon))
                        .foregroundColor(.redmedMuted.opacity(0.45))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear birth date")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.rowHPad)
        .padding(.vertical, Metrics.rowVPad)
    }

    private var birthDatePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Birth date",
                    selection: $pickerBirthDate,
                    in: Self.birthDateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(.redmedAccent)
                .padding(.top, 8)
                Spacer()
            }
            .navigationTitle("Birth date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.redmedBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBirthDatePicker = false }
                        .foregroundColor(.redmedAccent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        birthDate = Self.birthDateFormatter.string(from: pickerBirthDate)
                        showBirthDatePicker = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.redmedAccent)
                }
            }
            .background { RedMedPageBackground() }
        }
        .presentationDetents([.medium])
    }

    private var bloodTypeRow: some View {
        HStack(spacing: 0) {
            Text("Blood type")
                .font(.system(size: Metrics.font, weight: .medium))
                .foregroundColor(.redmedMuted)
                .frame(width: Metrics.labelWidth, alignment: .leading)
                .padding(.trailing, 12)

            Button {
                showBloodTypePicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(bloodType.isEmpty ? "Select" : bloodType)
                        .font(.system(size: Metrics.font, weight: .medium))
                        .foregroundColor(bloodType.isEmpty ? .redmedAccent : .redmedDark)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.rowHPad)
        .padding(.vertical, Metrics.rowVPad)
    }

    // MARK: - Contacts

    @ViewBuilder
    private var contactsEditor: some View {
        ForEach($contacts) { $contact in
            ContactDraftRow(contact: $contact) {
                let id = contact.id
                contacts.removeAll { $0.id == id }
            }
            .id(contact.id)
        }

        Button {
            contacts.append(EmergencyContact(name: "", relationship: "", phone: ""))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: Metrics.icon))
                Text("Add contact").font(.system(size: Metrics.font, weight: .medium))
            }
            .foregroundColor(.redmedAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared chrome

    @ViewBuilder
    private func editSectionLabel(_ text: String) -> some View {
        // Same SectionLabel metrics as Help / NFC cards — even rhythm across modals.
        SectionLabel(text: text == "You" ? "You" : text)
            .padding(.top, text == "You" ? 0 : Metrics.sectionGap)
    }

    @ViewBuilder
    private func editCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        // flatten: false — wraps live TextFields; re-rasterizing on every
        // keystroke would cost more than the GPU flatten saves.
        VStack(spacing: 0) { content() }
            .redmedBox(flatten: false)
    }

    // MARK: - Persistence

    private static func parseBirthDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in birthDateParsers {
            if let date = formatter.date(from: trimmed) { return date }
        }
        for style: DateFormatter.Style in [.medium, .long, .short] {
            let f = DateFormatter()
            f.dateStyle = style
            f.timeStyle = .none
            if let date = f.date(from: trimmed) { return date }
        }
        return nil
    }

    private func loadDraft() {
        youFullName = profile.name
        birthDate = profile.birthDate
        bloodType = profile.bloodType
        isOrganDonor = profile.isOrganDonor
        // Empty profile → empty sections (Add rows only). Never seed blank entries.
        allergies = profile.allergies.map { DraftLine(text: $0) }
        medications = profile.medications.map { DraftLine(text: $0) }
        conditions = profile.conditions.map { DraftLine(text: $0) }
        contacts = profile.contacts
        applyHealthSeed()
    }

    private func applyHealthSeed() {
        guard let seed = healthSeed else { return }
        if birthDate.isEmpty, let dob = seed.birthDate { birthDate = dob }
        if bloodType.isEmpty, let blood = seed.bloodType { bloodType = blood }
    }

    @ViewBuilder
    private var healthImportCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Task { await importFromHealth() }
            } label: {
                HStack(spacing: 8) {
                    if healthImportBusy {
                        ProgressView().tint(.redmedAccent)
                    } else {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: Metrics.icon, weight: .semibold))
                    }
                    Text(healthImportBusy ? "Reading Apple Health…" : "Fill from Apple Health")
                        .font(.system(size: Metrics.font, weight: .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedMuted.opacity(0.55))
                        .opacity(healthImportBusy ? 0 : 1)
                }
                .foregroundColor(.redmedAccent)
                .padding(.horizontal, Metrics.rowHPad)
                .padding(.vertical, Metrics.rowVPad)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(healthImportBusy)

            Divider().padding(.leading, Metrics.rowHPad)

            Text("Birth date and blood type only. Empty fields are filled; existing values stay. RedMed never writes back to Health.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.redmedMuted)
                .padding(.horizontal, Metrics.rowHPad)
                .padding(.vertical, 12)

            if let healthImportMessage, !healthImportMessage.isEmpty {
                Divider().padding(.leading, Metrics.rowHPad)
                Text(healthImportMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .padding(.horizontal, Metrics.rowHPad)
                    .padding(.vertical, 12)
            }
        }
        .redmedBox()
        .padding(.top, 12)
    }

    @MainActor
    private func importFromHealth() async {
        guard !isScannerSession, !healthImportBusy else { return }
        healthImportBusy = true
        healthImportMessage = nil
        defer { healthImportBusy = false }
        do {
            let draft = try await HealthKitProfileImport.readCharacteristics()
            var filled: [String] = []
            if birthDate.isEmpty, let dob = draft.birthDate {
                birthDate = dob
                filled.append("birth date")
            }
            if bloodType.isEmpty, let blood = draft.bloodType {
                bloodType = blood
                filled.append("blood type")
            }
            if filled.isEmpty {
                healthImportMessage = "Those fields are already filled."
            } else {
                healthImportMessage = "Filled \(filled.joined(separator: " and ")). Save to keep them."
            }
        } catch {
            healthImportMessage = error.localizedDescription
        }
    }

    /// Custom `UIViewRepresentable` text fields never resign first responder
    /// on their own. Dismissing the sheet (Save/Cancel) while one still holds
    /// the keyboard fights the modal teardown and freezes the UI for several
    /// seconds — resign before every dismiss path.
    private static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func save() {
        Self.dismissKeyboard()
        guard !isScannerSession else {
            dismiss()
            return
        }
        let reason = requireAuthOnSave
            ? "Confirm with Face ID, Touch ID, or passcode to save your RedMed profile."
            : "Confirm with Face ID, Touch ID, or passcode to update your RedMed profile."
        BiometricAuth.authenticate(
            reason: reason,
            force: true
        ) { outcome in
            if outcome == .success {
                commitSave()
            } else if outcome == .notVerified {
                showAuthFailedAlert = true
                VaultHistoryStore.shared.record(.unlockFailed, detail: "editSave")
            }
        }
    }

    private func commitSave() {
        let nextName = youFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextBirth: String = {
            if let date = Self.parseBirthDate(birthDate) {
                return Self.birthDateFormatter.string(from: date)
            }
            return birthDate.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        let nextBlood = bloodType.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextAllergies = allergies.map(\.text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let nextMeds = medications.map(\.text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let nextConditions = conditions.map(\.text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let nextContacts = contacts.compactMap { contact -> EmergencyContact? in
            let trimmedName = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPhone = contact.phone.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRel = contact.relationship.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty || !trimmedPhone.isEmpty else { return nil }
            return EmergencyContact(
                name: trimmedName,
                relationship: trimmedRel,
                phone: trimmedPhone
            )
        }

        let changed =
            nextName != profile.name
            || nextBirth != profile.birthDate
            || nextBlood != profile.bloodType
            || isOrganDonor != profile.isOrganDonor
            || nextAllergies != profile.allergies
            || nextMeds != profile.medications
            || nextConditions != profile.conditions
            || nextContacts.map { "\($0.name)|\($0.relationship)|\($0.phone)" }
                != profile.contacts.map { "\($0.name)|\($0.relationship)|\($0.phone)" }

        let prior = profile.snapshot()
        profile.name = nextName
        profile.birthDate = nextBirth
        profile.bloodType = nextBlood
        profile.isOrganDonor = isOrganDonor
        profile.allergies = nextAllergies
        profile.medications = nextMeds
        profile.conditions = nextConditions
        profile.contacts = nextContacts

        // Band holds a snapshot — real edits unpair until NFC rewrite.
        if changed {
            profile.clearBraceletPairingAfterProfileEdit()
        }

        guard profile.persist() else {
            profile.restore(from: prior)
            showSaveFailedAlert = true
            return
        }
        VaultHistoryStore.shared.record(.profileSaved)
        dismiss()
    }
}

// MARK: - Draft lines

struct DraftLine: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(text: String = "", id: UUID = UUID()) {
        self.id = id
        self.text = text
    }
}

/// Isolated so list/contact fields cannot reuse this field's UIKit coordinator.
private struct YouNameField: View {
    @Binding var text: String

    var body: some View {
        IdentifiedTextField(
            fieldID: "edit-you-full-name",
            placeholder: "Full name",
            text: $text,
            autocapitalization: .words
        )
    }
}

/// One emergency-contact block. Own view + per-control ids — `$contact.name`
/// lived next to You `$youFullName` in the same body and typed into the You name field.
private struct ContactDraftRow: View {
    @Binding var contact: EmergencyContact
    var onDelete: () -> Void

    @State private var country: CountryDialCode
    @State private var localNumber: String

    private enum Metrics {
        static let font: CGFloat = 15
        static let icon: CGFloat = 18
        static let rowHPad: CGFloat = 16
        static let rowVPad: CGFloat = 13
    }

    private var contactID: String { contact.id.uuidString }

    init(contact: Binding<EmergencyContact>, onDelete: @escaping () -> Void) {
        self._contact = contact
        self.onDelete = onDelete
        let parsed = CountryDialCode.parse(contact.wrappedValue.phone)
        self._country = State(initialValue: parsed.country)
        let initialDisplay = parsed.country.dialCode == "+1"
            ? CountryDialCode.formattedNANP(digits: parsed.localNumber)
            : parsed.localNumber
        self._localNumber = State(initialValue: initialDisplay)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                IdentifiedTextField(
                    fieldID: "edit-contact-\(contactID)-name",
                    placeholder: "Contact name",
                    text: $contact.name,
                    autocapitalization: .words
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDelete) {
                    Text("✕")
                        .font(.system(size: Metrics.icon))
                        .foregroundColor(.redmedAccent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    contact.name.isEmpty
                        ? "Delete contact"
                        : "Delete contact \(contact.name)"
                )
            }
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)

            Divider().padding(.leading, Metrics.rowHPad)

            HStack(spacing: 10) {
                Menu {
                    ForEach(CountryDialCode.all) { c in
                        Button {
                            country = c
                            syncPhone(number: localNumber)
                        } label: {
                            if c.iso == country.iso {
                                Label("\(c.flag) \(c.name) \(c.dialCode)", systemImage: "checkmark")
                            } else {
                                Text("\(c.flag) \(c.name) \(c.dialCode)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(country.flag)
                        Text(country.dialCode)
                            .font(.system(size: Metrics.font, weight: .medium))
                            .foregroundColor(.redmedDark)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Country code: \(country.name) \(country.dialCode)")

                IdentifiedTextField(
                    fieldID: "edit-contact-\(contactID)-phone",
                    placeholder: "Phone number",
                    text: $localNumber,
                    keyboardType: .phonePad,
                    autocapitalization: .none,
                    onChange: syncPhone
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)

            Divider().padding(.leading, Metrics.rowHPad)

            IdentifiedTextField(
                fieldID: "edit-contact-\(contactID)-rel",
                placeholder: "Relation (optional)",
                text: $contact.relationship,
                autocapitalization: .words
            )
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)

            Divider().padding(.leading, Metrics.rowHPad)
        }
        .id("edit-contact-row-\(contactID)")
    }

    private func syncPhone(number: String) {
        // +1 (US/Canada, NANP): reformat live to (XXX) XXX-XXXX with the area
        // code grouped — other countries keep the raw digits as typed since
        // NANP grouping doesn't apply to their numbering plans.
        let display = country.dialCode == "+1"
            ? CountryDialCode.formattedNANP(digits: number)
            : number.trimmingCharacters(in: .whitespaces)
        if display != localNumber { localNumber = display }
        contact.phone = display.isEmpty ? "" : "\(country.dialCode) \(display)"
    }
}

/// Edit rows: padding 13/16, TextField + ✕. No FocusState — sheet-wide focus
/// tracking hung Edit. Suggestions live in a fixed bottom strip via onTextChange.
private struct DraftLinesEditor: View {
    @Binding var lines: [DraftLine]
    let sectionKey: String
    let placeholder: String
    let addLabel: String
    var onTextChange: ((UUID, String) -> Void)? = nil

    private enum Metrics {
        static let font: CGFloat = 15
        static let icon: CGFloat = 18
        static let rowHPad: CGFloat = 16
        static let rowVPad: CGFloat = 13
    }

    var body: some View {
        ForEach($lines) { $line in
            DraftLineRow(
                line: $line,
                sectionKey: sectionKey,
                placeholder: placeholder,
                onTextChange: onTextChange
            ) {
                let id = line.id
                onTextChange?(id, "")
                lines.removeAll { $0.id == id }
            }
            .id(line.id)
        }

        Button {
            lines.append(DraftLine())
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: Metrics.icon))
                Text(addLabel).font(.system(size: Metrics.font, weight: .medium))
            }
            .foregroundColor(.redmedAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DraftLineRow: View {
    @Binding var line: DraftLine
    let sectionKey: String
    let placeholder: String
    var onTextChange: ((UUID, String) -> Void)?
    var onDelete: () -> Void

    private enum Metrics {
        static let font: CGFloat = 15
        static let icon: CGFloat = 18
        static let rowHPad: CGFloat = 16
        static let rowVPad: CGFloat = 13
    }

    private var fieldID: String { "edit-\(sectionKey)-\(line.id.uuidString)" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                IdentifiedTextField(
                    fieldID: fieldID,
                    placeholder: placeholder,
                    text: $line.text,
                    autocapitalization: .words,
                    onChange: { onTextChange?(line.id, $0) }
                )
                Button(action: onDelete) {
                    Text("✕")
                        .font(.system(size: Metrics.icon))
                        .foregroundColor(.redmedAccent)
                        .padding(.leading, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    line.text.isEmpty
                        ? "Delete \(placeholder.lowercased())"
                        : "Delete \(placeholder.lowercased()) \(line.text)"
                )
            }
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)
            Divider().padding(.leading, Metrics.rowHPad)
        }
        .id(fieldID + "-row")
    }
}

/// One UITextField per id. SwiftUI `TextField` reused the first coordinator
/// (You name), so list typing landed in `profile.name` and painted on both
/// the owner YOU card and passerby tapper.
private struct IdentifiedTextField: View {
    let fieldID: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .words
    var textAlignment: NSTextAlignment = .left
    var onChange: ((String) -> Void)? = nil

    var body: some View {
        RepresentedField(
            fieldID: fieldID,
            placeholder: placeholder,
            text: $text,
            keyboardType: keyboardType,
            autocapitalization: autocapitalization,
            textAlignment: textAlignment,
            onChange: onChange
        )
        .id(fieldID)
        .frame(minHeight: 22)
    }
}

private struct RepresentedField: UIViewRepresentable {
    let fieldID: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .words
    var textAlignment: NSTextAlignment = .left
    var onChange: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onChange: onChange)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = .systemFont(ofSize: 15)
        tf.textColor = UIColor(Color.redmedDark)
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.keyboardType = keyboardType
        tf.autocapitalizationType = autocapitalization
        // PHI fields: minimize system dictionary / autofill / keyboard learning.
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.smartDashesType = .no
        tf.smartQuotesType = .no
        tf.smartInsertDeleteType = .no
        tf.textContentType = nil
        tf.passwordRules = nil
        // Clear input assistant bar groups (reduces some keyboard chrome / suggestion surface).
        tf.inputAssistantItem.leadingBarButtonGroups = []
        tf.inputAssistantItem.trailingBarButtonGroups = []
        tf.textAlignment = textAlignment
        tf.accessibilityIdentifier = fieldID
        tf.accessibilityLabel = placeholder
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.setContentHuggingPriority(.required, for: .vertical)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onChange = onChange
        if tf.text != text {
            tf.text = text
        }
        if tf.placeholder != placeholder {
            tf.placeholder = placeholder
        }
        if tf.keyboardType != keyboardType {
            tf.keyboardType = keyboardType
        }
        if tf.autocapitalizationType != autocapitalization {
            tf.autocapitalizationType = autocapitalization
        }
        if tf.textAlignment != textAlignment {
            tf.textAlignment = textAlignment
        }
        // Keep lockdown traits if UIKit resets them on reuse.
        if tf.autocorrectionType != .no { tf.autocorrectionType = .no }
        if tf.spellCheckingType != .no { tf.spellCheckingType = .no }
        if tf.smartInsertDeleteType != .no { tf.smartInsertDeleteType = .no }
        if tf.textContentType != nil { tf.textContentType = nil }
        tf.accessibilityIdentifier = fieldID
    }

    final class Coordinator: NSObject {
        var text: Binding<String>
        var onChange: ((String) -> Void)?

        init(text: Binding<String>, onChange: ((String) -> Void)?) {
            self.text = text
            self.onChange = onChange
        }

        @objc func editingChanged(_ sender: UITextField) {
            let value = sender.text ?? ""
            text.wrappedValue = value
            onChange?(value)
        }
    }
}
