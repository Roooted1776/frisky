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

    /// One focus domain for the whole sheet — separate FocusStates per section freeze
    /// when moving between You / Allergies / Meds / Conditions / Contacts.
    @FocusState private var focus: EditFocus?

    private static let bloodTypeChoices = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]

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

    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { Self.parseBirthDate(birthDate) ?? Self.defaultBirthDate },
            set: { birthDate = Self.birthDateFormatter.string(from: $0) }
        )
    }

    var body: some View {
        if isScannerSession {
            Color.clear.onAppear { dismiss() }
        } else {
            editorBody
        }
    }

    private var editorBody: some View {
        VStack(spacing: 0) {
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
                    editSectionLabel("You")
                    editCard {
                        nameRow
                        Divider().padding(.leading, 106)
                        birthDateRow
                        Divider().padding(.leading, 106)
                        bloodTypeRow
                    }

                    editSectionLabel("Allergies")
                    editCard {
                        DraftLinesEditor(
                            lines: $allergies,
                            focus: $focus,
                            placeholder: "Allergy",
                            catalog: commonAllergies,
                            addLabel: "Add allergy"
                        )
                    }

                    editSectionLabel("Medications")
                    editCard {
                        DraftLinesEditor(
                            lines: $medications,
                            focus: $focus,
                            placeholder: "Medication",
                            catalog: commonMedications,
                            addLabel: "Add medication"
                        )
                    }

                    editSectionLabel("Conditions")
                    editCard {
                        DraftLinesEditor(
                            lines: $conditions,
                            focus: $focus,
                            placeholder: "Condition",
                            catalog: commonConditions,
                            addLabel: "Add condition"
                        )
                    }

                    editSectionLabel("Emergency Contacts")
                    editCard {
                        contactsEditor
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

    // MARK: - You

    private var nameRow: some View {
        HStack(spacing: 0) {
            Text("Name")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                .frame(width: 90, alignment: .leading)
                .padding(.trailing, 12)
            TextField("Full name", text: $name)
                .font(.system(size: 15))
                .foregroundColor(.redmedDark)
                .focused($focus, equals: .name)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
    }

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
                    focus = nil
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

    // MARK: - Contacts

    private var contactsEditor: some View {
        ForEach($contacts) { $contact in
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Name", text: $contact.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.redmedDark)
                        .focused($focus, equals: .contactName(contact.id))
                    TextField("Relationship · phone", text: $contact.detail)
                        .font(.system(size: 13))
                        .foregroundColor(.redmedMuted)
                        .focused($focus, equals: .contactDetail(contact.id))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())

                Button {
                    let id = contact.id
                    switch focus {
                    case .contactName(id), .contactDetail(id):
                        focus = nil
                    default:
                        break
                    }
                    contacts.removeAll { $0.id == id }
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
            Divider().padding(.leading, 16)
        }

        Button {
            focus = nil
            contacts.append(EmergencyContact(name: "", detail: ""))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                Text("Add contact").font(.system(size: 15))
            }
            .foregroundColor(.redmedAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared chrome

    @ViewBuilder
    private func editSectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
            .kerning(0.5)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
            .padding(.top, text == "You" ? 0 : 22)
    }

    @ViewBuilder
    private func editCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

// MARK: - Focus

private enum EditFocus: Hashable {
    case name
    case line(UUID)
    case contactName(UUID)
    case contactDetail(UUID)
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

/// Allergy / med / condition editor. Shares the sheet-wide focus so jumping
/// between sections stays reactive. Suggestions are cached in the row and only
/// refresh on text/focus changes — not on every parent body pass.
private struct DraftLinesEditor: View {
    @Binding var lines: [DraftLine]
    var focus: FocusState<EditFocus?>.Binding
    let placeholder: String
    let catalog: [String]
    let addLabel: String

    var body: some View {
        ForEach($lines) { $line in
            DraftLineRow(
                line: $line,
                lines: $lines,
                placeholder: placeholder,
                catalog: catalog,
                focus: focus,
                onRemove: { remove(line.id) }
            )
        }

        Button {
            focus.wrappedValue = nil
            lines.append(DraftLine())
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                Text(addLabel).font(.system(size: 15))
            }
            .foregroundColor(.redmedAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func remove(_ id: UUID) {
        if focus.wrappedValue == .line(id) { focus.wrappedValue = nil }
        lines.removeAll { $0.id == id }
    }
}

private struct DraftLineRow: View {
    @Binding var line: DraftLine
    @Binding var lines: [DraftLine]
    let placeholder: String
    let catalog: [String]
    var focus: FocusState<EditFocus?>.Binding
    let onRemove: () -> Void

    @State private var matches: [String] = []

    private var isFocused: Bool { focus.wrappedValue == .line(line.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                TextField(placeholder, text: $line.text)
                    .font(.system(size: 15))
                    .foregroundColor(.redmedDark)
                    .focused(focus, equals: .line(line.id))
                    .onChange(of: line.text) { _, newValue in
                        guard isFocused else { return }
                        refreshMatches(newValue)
                    }
                Spacer(minLength: 0)
                Button(action: onRemove) {
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

            if isFocused, !matches.isEmpty {
                VStack(spacing: 0) {
                    ForEach(matches, id: \.self) { suggestion in
                        Button {
                            line.text = suggestion
                            matches = []
                            focus.wrappedValue = nil
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
        .onChange(of: focus.wrappedValue) { _, newFocus in
            if newFocus == .line(line.id) {
                refreshMatches(line.text)
            } else if !matches.isEmpty {
                matches = []
            }
        }
        Divider().padding(.leading, 16)
    }

    private func refreshMatches(_ raw: String) {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            if !matches.isEmpty { matches = [] }
            return
        }
        let queryLower = query.lowercased()
        let rowID = line.id
        let taken = Set(
            lines.lazy
                .filter { $0.id != rowID }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        var next: [String] = []
        next.reserveCapacity(5)
        for suggestion in catalog {
            let value = suggestion.lowercased()
            if value == queryLower { continue }
            if taken.contains(value) { continue }
            guard value.contains(queryLower) else { continue }
            next.append(suggestion)
            if next.count == 5 { break }
        }
        if next != matches { matches = next }
    }
}
