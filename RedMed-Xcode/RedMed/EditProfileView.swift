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
    @State private var allergies: [DraftLine] = []
    @State private var medications: [DraftLine] = []
    @State private var conditions: [DraftLine] = []
    @State private var contacts: [EmergencyContact] = []
    @State private var showAuthFailedAlert = false

    /// Display / persist as "Month DD, YYYY" (matches the old text placeholder).
    private static let birthDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    /// Accept existing free-typed values when opening Edit.
    private static let birthDateParsers: [DateFormatter] = {
        let formats = ["MMMM d, yyyy", "MMM d, yyyy", "M/d/yyyy", "MM/dd/yyyy", "yyyy-MM-dd"]
        return formats.map { format in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            return f
        }
    }()

    private static var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .year, value: -120, to: Date()) ?? Date.distantPast
        return start...Date()
    }

    private static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    }

    /// Only valid once `birthDate` parses — never invent a date for an empty field.
    private var birthDateBinding: Binding<Date> {
        Binding(
            get: {
                Self.parseBirthDate(birthDate) ?? Self.defaultBirthDate
            },
            set: {
                birthDate = Self.birthDateFormatter.string(from: $0)
            }
        )
    }

    private var hasBirthDate: Bool {
        Self.parseBirthDate(birthDate) != nil
    }

    var body: some View {
        // Ped/EMS scanners never edit — dismiss if this view is ever presented.
        if isScannerSession {
            Color.clear
                .onAppear { dismiss() }
        } else {
            editorBody
        }
    }

    private var editorBody: some View {
        VStack(spacing: 0) {
            // Sheet nav bar
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 17))
                    .foregroundColor(.redmedAccent)
                Spacer()
                Text("Edit RedMed")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.redmedDark)
                Spacer()
                Button("Save") { save() }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.redmedAccent)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(red: 0.949, green: 0.949, blue: 0.969).opacity(0.95))
            .overlay(alignment: .bottom) {
                Divider().overlay(Color.black.opacity(0.12))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // YOU
                    editSectionLabel("You")
                    editCard {
                        editRow(label: "Name", text: $name, placeholder: "Full name")
                        Divider().padding(.leading, 106)
                        birthDateRow
                        Divider().padding(.leading, 106)
                        bloodTypeRow
                    }

                    // ALLERGIES / MEDICATIONS / CONDITIONS — normal list rows
                    editSectionLabel("Allergies")
                    editCard {
                        DraftLinesEditor(
                            lines: $allergies,
                            placeholder: "Allergy",
                            catalog: commonAllergies,
                            addLabel: "Add allergy"
                        )
                    }

                    editSectionLabel("Medications")
                    editCard {
                        DraftLinesEditor(
                            lines: $medications,
                            placeholder: "Medication",
                            catalog: commonMedications,
                            addLabel: "Add medication"
                        )
                    }

                    editSectionLabel("Conditions")
                    editCard {
                        DraftLinesEditor(
                            lines: $conditions,
                            placeholder: "Condition",
                            catalog: commonConditions,
                            addLabel: "Add condition"
                        )
                    }

                    // CONTACTS
                    editSectionLabel("Emergency Contacts")
                    editCard {
                        ForEach($contacts) { $contact in
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("Name", text: $contact.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.redmedDark)
                                    TextField("Relationship · phone", text: $contact.detail)
                                        .font(.system(size: 13))
                                        .foregroundColor(.redmedMuted)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                                removeLineButton {
                                    withAnimation { contacts.removeAll { $0.id == contact.id } }
                                }
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, 4)
                            Divider().padding(.leading, 16)
                        }
                        addButton("Add contact") { contacts.append(EmergencyContact(name: "", detail: "")) }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(red: 0.949, green: 0.949, blue: 0.969))
        }
        .onAppear { loadDraft() }
        .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to save your RedMed profile.")
        }
    }

    // MARK: - Helpers
    @ViewBuilder
    func editSectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
            .kerning(0.5)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
            .padding(.top, (text == "You") ? 0 : 22)
    }

    @ViewBuilder
    func editCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    func editRow(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                .frame(width: 90, alignment: .leading)
                .padding(.trailing, 12)
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundColor(.redmedDark)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
    }

    private static let bloodTypeChoices = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]

    /// Compact DatePicker — empty stays empty (no fake default on screen).
    /// Tap “Select date” to seed, then use the system compact picker.
    private var birthDateRow: some View {
        HStack(spacing: 0) {
            Text("Birth date")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                .frame(width: 90, alignment: .leading)
                .padding(.trailing, 12)

            if hasBirthDate {
                DatePicker(
                    "",
                    selection: birthDateBinding,
                    in: Self.birthDateRange,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(.redmedAccent)

                Button {
                    birthDate = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48).opacity(0.45))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear birth date")
            } else {
                Button {
                    birthDate = Self.birthDateFormatter.string(from: Self.defaultBirthDate)
                } label: {
                    Text("Select date")
                        .font(.system(size: 15))
                        .foregroundColor(.redmedAccent)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, hasBirthDate ? 10 : 0)
    }

    /// Closed-set blood type — Menu instead of free text (avoids O+ vs 0+ typos).
    private var bloodTypeRow: some View {
        HStack(spacing: 0) {
            Text("Blood type")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                .frame(width: 90, alignment: .leading)
                .padding(.trailing, 12)

            Menu {
                Button("Clear") { bloodType = "" }
                ForEach(Self.bloodTypeChoices, id: \.self) { type in
                    Button(type) { bloodType = type }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(bloodType.isEmpty ? "Select" : bloodType)
                        .font(.system(size: 15))
                        .foregroundColor(bloodType.isEmpty ? .redmedAccent : .redmedDark)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48).opacity(0.55))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private static func parseBirthDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in birthDateParsers {
            if let date = formatter.date(from: trimmed) { return date }
        }
        // Last resort: locale medium/long styles from older typed entries.
        let styles: [DateFormatter.Style] = [.medium, .long, .short]
        for style in styles {
            let f = DateFormatter()
            f.dateStyle = style
            f.timeStyle = .none
            if let date = f.date(from: trimmed) { return date }
        }
        return nil
    }

    @ViewBuilder
    func addButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 15))
            }
            .foregroundColor(.redmedAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 13)
            // Plain buttons only hit opaque glyphs unless the full row is shaped.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// ✕ removes the row from the draft list. Large hit target so TextField
    /// focus doesn't steal the tap (same plain + contentShape pattern as Add).
    @ViewBuilder
    func removeLineButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("✕")
                .font(.system(size: 18))
                .foregroundColor(.redmedAccent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadDraft() {
        name = profile.name
        birthDate = profile.birthDate
        bloodType = profile.bloodType
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
        // First-time fill opens Edit without Face ID — confirm identity before Keychain write.
        // Returning edits already unlocked via RedMed Edit, so Save skips a second prompt.
        if requireAuthOnSave {
            BiometricAuth.authenticate(
                reason: "Confirm with Face ID, Touch ID, or passcode to save your RedMed profile."
            ) { success in
                if success {
                    commitSave()
                } else {
                    showAuthFailedAlert = true
                }
            }
            return
        }
        commitSave()
    }

    private func commitSave() {
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Normalize any legacy free-typed value to the DatePicker format on save.
        if let date = Self.parseBirthDate(birthDate) {
            profile.birthDate = Self.birthDateFormatter.string(from: date)
        } else {
            profile.birthDate = birthDate.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        profile.bloodType = bloodType.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.allergies = allergies.map(\.text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        profile.medications = medications.map(\.text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        profile.conditions = conditions.map(\.text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        profile.contacts = contacts.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        profile.persist()
        dismiss()
    }
}

/// Stable identity for editable string rows (avoids ForEach index-as-id crashes on delete).
struct DraftLine: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(text: String = "", id: UUID = UUID()) {
        self.id = id
        self.text = text
    }
}

/// Normal Edit list: one TextField + ✕ per row, suggestions under the focused row only.
/// Uses value-ForEach + id-keyed bindings so delete works on the first row and
/// autocomplete works on every row (not just the first).
private struct DraftLinesEditor: View {
    @Binding var lines: [DraftLine]
    let placeholder: String
    let catalog: [String]
    let addLabel: String

    @FocusState private var focusedID: UUID?

    var body: some View {
        ForEach(lines) { line in
            let rowID = line.id
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    TextField(placeholder, text: textBinding(for: rowID))
                        .font(.system(size: 15))
                        .foregroundColor(.redmedDark)
                        .focused($focusedID, equals: rowID)
                    Spacer(minLength: 0)
                    Button {
                        focusedID = nil
                        lines.removeAll { $0.id == rowID }
                    } label: {
                        Text("✕")
                            .font(.system(size: 18))
                            .foregroundColor(.redmedAccent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 16)
                .padding(.trailing, 4)

                if focusedID == rowID {
                    let matches = suggestions(for: rowID)
                    if !matches.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(matches, id: \.self) { suggestion in
                                Button {
                                    if let idx = lines.firstIndex(where: { $0.id == rowID }) {
                                        lines[idx].text = suggestion
                                    }
                                    focusedID = nil
                                } label: {
                                    Text(suggestion)
                                        .font(.system(size: 14))
                                        .foregroundColor(.redmedDark)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Color.redmedAccent.opacity(0.06))
                        .padding(.bottom, 8)
                    }
                }
            }
            Divider().padding(.leading, 16)
        }

        Button {
            focusedID = nil
            let next = DraftLine()
            lines.append(next)
            DispatchQueue.main.async {
                focusedID = next.id
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text(addLabel)
                    .font(.system(size: 15))
            }
            .foregroundColor(.redmedAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func textBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { lines.first(where: { $0.id == id })?.text ?? "" },
            set: { newValue in
                guard let idx = lines.firstIndex(where: { $0.id == id }) else { return }
                lines[idx].text = newValue
            }
        )
    }

    private func suggestions(for id: UUID) -> [String] {
        guard let line = lines.first(where: { $0.id == id }) else { return [] }
        let query = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let queryLower = query.lowercased()
        let taken = Set(
            lines
                .filter { $0.id != id }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        return Array(
            catalog
                .filter { suggestion in
                    let value = suggestion.lowercased()
                    if value == queryLower { return false }
                    if taken.contains(value) { return false }
                    return suggestion.localizedCaseInsensitiveContains(query)
                }
                .prefix(5)
        )
    }
}
