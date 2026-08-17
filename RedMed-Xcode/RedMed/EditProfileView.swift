import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.dismiss) var dismiss
    @Environment(\.isScannerSession) private var isScannerSession

    /// True when Edit opened without Face ID (first fill). Save then requires biometrics.
    var requireAuthOnSave: Bool = false

    @State private var name = ""
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
            OwnerModalChrome(
                title: "Edit",
                leadingTitle: "Cancel",
                leadingAction: { dismiss() }
            ) {
                HStack(spacing: 12) {
                    OwnerHelpButton()
                    OwnerModalTrailingAction(title: "Save", action: save)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    editSectionLabel("You")
                    editCard {
                        youRow(label: "Name") {
                            TextField("Full name", text: $name)
                                .font(.system(size: Metrics.font))
                                .foregroundColor(.redmedDark)
                                .vaultSafeTextInput(capitalization: .words)
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

                    editSectionLabel("Allergies")
                    editCard {
                        DraftLinesEditor(
                            lines: $allergies,
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
        .presentsOwnerHelp()
        .onAppear {
            loadDraft()
            SuggestionCatalog.warmUp()
        }
        .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to save your RedMed profile.")
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
                Divider().overlay(Color.black.opacity(0.12))
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
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        suggestionLineID = lineID
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
            HStack(alignment: .center, spacing: 10) {
                TextField("Name", text: $contact.name)
                    .font(.system(size: Metrics.font))
                    .foregroundColor(.redmedDark)
                    .vaultSafeTextInput(capitalization: .words)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Phone", text: $contact.phone)
                    .font(.system(size: Metrics.font))
                    .foregroundColor(.redmedDark)
                    .keyboardType(.phonePad)
                    .vaultSafeTextInput(capitalization: .never)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Button {
                    let id = contact.id
                    contacts.removeAll { $0.id == id }
                } label: {
                    Text("✕")
                        .font(.system(size: Metrics.icon))
                        .foregroundColor(.redmedAccent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)

            Divider().padding(.leading, Metrics.rowHPad)

            TextField("Relation (optional)", text: $contact.relationship)
                .font(.system(size: Metrics.font))
                .foregroundColor(.redmedDark)
                .vaultSafeTextInput(capitalization: .words)
                .padding(.horizontal, Metrics.rowHPad)
                .padding(.vertical, Metrics.rowVPad)

            Divider().padding(.leading, Metrics.rowHPad)
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
        VStack(spacing: 0) { content() }
            .redmedBox()
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
        name = profile.name
        birthDate = profile.birthDate
        bloodType = profile.bloodType
        isOrganDonor = profile.isOrganDonor
        // Empty profile → empty sections (Add rows only). Never seed blank entries.
        allergies = profile.allergies.map { DraftLine(text: $0) }
        medications = profile.medications.map { DraftLine(text: $0) }
        conditions = profile.conditions.map { DraftLine(text: $0) }
        contacts = profile.contacts
    }

    private func save() {
        guard !isScannerSession else {
            dismiss()
            return
        }
        if requireAuthOnSave {
            BiometricAuth.authenticate(
                reason: "Confirm with Face ID, Touch ID, or passcode to save your RedMed profile."
            ) { outcome in
                if outcome == .success {
                    commitSave()
                } else if outcome == .notVerified {
                    showAuthFailedAlert = true
                    VaultHistoryStore.shared.record(.unlockFailed, detail: "editSave")
                }
            }
            return
        }
        commitSave()
    }

    private func commitSave() {
        let nextName = name.trimmingCharacters(in: .whitespacesAndNewlines)
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

/// Edit rows: padding 13/16, TextField + ✕. No FocusState — sheet-wide focus
/// tracking hung Edit. Suggestions live in a fixed bottom strip via onTextChange.
private struct DraftLinesEditor: View {
    @Binding var lines: [DraftLine]
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
            HStack(spacing: 0) {
                TextField(placeholder, text: $line.text)
                    .font(.system(size: Metrics.font))
                    .foregroundColor(.redmedDark)
                    .vaultSafeTextInput(capitalization: .words)
                    .onChange(of: line.text) { _, newValue in
                        onTextChange?(line.id, newValue)
                    }
                Button {
                    let id = line.id
                    onTextChange?(id, "")
                    lines.removeAll { $0.id == id }
                } label: {
                    Text("✕")
                        .font(.system(size: Metrics.icon))
                        .foregroundColor(.redmedAccent)
                        .padding(.leading, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Metrics.rowHPad)
            .padding(.vertical, Metrics.rowVPad)
            Divider().padding(.leading, Metrics.rowHPad)
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
