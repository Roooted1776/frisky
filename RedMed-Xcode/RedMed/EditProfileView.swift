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

    /// Matches for the focused allergy/med/condition row. Shown in a bottom
    /// strip (HTML datalist-style) so rows never grow/shrink while typing.
    @State private var suggestionMatches: [String] = []

    /// One focus domain for the whole sheet.
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
                            focus: $focus,
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
                            focus: $focus,
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
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(red: 0.949, green: 0.949, blue: 0.969))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                suggestionStrip
            }
        }
        .onAppear { loadDraft() }
        .onChange(of: focus) { _, newFocus in
            guard case .line(let id) = newFocus else {
                if !suggestionMatches.isEmpty { suggestionMatches = [] }
                return
            }
            if let hit = focusedLine(id: id) {
                refreshSuggestions(lineID: id, text: hit.text, lines: hit.lines, catalog: hit.catalog)
            } else if !suggestionMatches.isEmpty {
                suggestionMatches = []
            }
        }
        .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to save your RedMed profile.")
        }
    }

    // MARK: - Suggestion strip (HTML datalist equivalent)

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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(red: 0.949, green: 0.949, blue: 0.969))
            }
        }
    }

    private func focusedLine(id: UUID) -> (text: String, lines: [DraftLine], catalog: [(display: String, lower: String)])? {
        if let line = allergies.first(where: { $0.id == id }) {
            return (line.text, allergies, SuggestionCatalog.allergies)
        }
        if let line = medications.first(where: { $0.id == id }) {
            return (line.text, medications, SuggestionCatalog.medications)
        }
        if let line = conditions.first(where: { $0.id == id }) {
            return (line.text, conditions, SuggestionCatalog.conditions)
        }
        return nil
    }

    private func refreshSuggestions(lineID: UUID, text: String, lines: [DraftLine], catalog: [(display: String, lower: String)]) {
        guard case .line(lineID) = focus else {
            if !suggestionMatches.isEmpty { suggestionMatches = [] }
            return
        }
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            if !suggestionMatches.isEmpty { suggestionMatches = [] }
            return
        }
        let queryLower = query.lowercased()
        let taken = Set(
            lines.lazy
                .filter { $0.id != lineID }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        var next: [String] = []
        next.reserveCapacity(5)
        for entry in catalog {
            if entry.lower == queryLower { continue }
            if taken.contains(entry.lower) { continue }
            guard entry.lower.contains(queryLower) else { continue }
            next.append(entry.display)
            if next.count == 5 { break }
        }
        if next != suggestionMatches { suggestionMatches = next }
    }

    private func applySuggestion(_ suggestion: String) {
        guard case .line(let id) = focus else { return }
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, hasBirthDate ? 10 : 13)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Contacts (Main.dc.html padding 13/16)

    @ViewBuilder
    private var contactsEditor: some View {
        ForEach($contacts) { $contact in
            HStack(alignment: .top, spacing: 8) {
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
                .frame(maxWidth: .infinity, alignment: .leading)

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
                        .padding(.leading, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
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

/// Main.dc.html row: padding 13/16, input + ✕. No inline suggestion panel —
/// autocomplete lives in the sheet bottom strip so the ScrollView stays stable.
private struct DraftLinesEditor: View {
    @Binding var lines: [DraftLine]
    var focus: FocusState<EditFocus?>.Binding
    let placeholder: String
    let addLabel: String
    let onTextChange: (_ id: UUID, _ text: String) -> Void

    var body: some View {
        ForEach($lines) { $line in
            HStack(spacing: 0) {
                TextField(placeholder, text: $line.text)
                    .font(.system(size: 15))
                    .foregroundColor(.redmedDark)
                    .focused(focus, equals: .line(line.id))
                    .onChange(of: line.text) { _, newValue in
                        onTextChange(line.id, newValue)
                    }
                Button {
                    let id = line.id
                    if focus.wrappedValue == .line(id) { focus.wrappedValue = nil }
                    lines.removeAll { $0.id == id }
                } label: {
                    Text("✕")
                        .font(.system(size: 18))
                        .foregroundColor(.redmedAccent)
                        .padding(.leading, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            Divider().padding(.leading, 16)
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
}
