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
    @State private var allergyFocusID: UUID? = nil
    @State private var medications: [DraftLine] = []
    @State private var medFocusID: UUID? = nil
    @State private var conditions: [DraftLine] = []
    @State private var conditionFocusID: UUID? = nil
    @State private var contacts: [EmergencyContact] = []
    @State private var showAuthFailedAlert = false

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
                        editRow(label: "Name",       text: $name,       placeholder: "Full name")
                        Divider().padding(.leading, 106)
                        editRow(label: "Birth date", text: $birthDate,  placeholder: "Month DD, YYYY")
                        Divider().padding(.leading, 106)
                        editRow(label: "Blood type", text: $bloodType,  placeholder: "A+, B−, O+…")
                    }

                    // ALLERGIES
                    editSectionLabel("Allergies")
                    editCard {
                        ForEach($allergies) { $line in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TextField("Allergy", text: $line.text)
                                        .font(.system(size: 15))
                                        .foregroundColor(.redmedDark)
                                        .onChange(of: line.text) { _, _ in allergyFocusID = line.id }
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            allergies.removeAll { $0.id == line.id }
                                            if allergyFocusID == line.id { allergyFocusID = nil }
                                        }
                                    } label: {
                                        Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 13)

                                if allergyFocusID == line.id && !line.text.isEmpty {
                                    let matches = commonAllergies.filter { $0.localizedCaseInsensitiveContains(line.text) }.prefix(5)
                                    if !matches.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(Array(matches), id: \.self) { suggestion in
                                                Button {
                                                    if let idx = allergies.firstIndex(where: { $0.id == line.id }) {
                                                        allergies[idx].text = suggestion
                                                    }
                                                    allergyFocusID = nil
                                                } label: {
                                                    Text(suggestion)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.redmedDark)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .padding(.horizontal, 16).padding(.vertical, 9)
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
                        addButton("Add allergy") { allergies.append(DraftLine()) }
                    }

                    // MEDICATIONS
                    editSectionLabel("Medications")
                    editCard {
                        ForEach($medications) { $line in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TextField("Medication", text: $line.text)
                                        .font(.system(size: 15))
                                        .foregroundColor(.redmedDark)
                                        .onChange(of: line.text) { _, _ in medFocusID = line.id }
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            medications.removeAll { $0.id == line.id }
                                            if medFocusID == line.id { medFocusID = nil }
                                        }
                                    } label: {
                                        Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 13)

                                if medFocusID == line.id && !line.text.isEmpty {
                                    let matches = commonMedications.filter { $0.localizedCaseInsensitiveContains(line.text) }.prefix(5)
                                    if !matches.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(Array(matches), id: \.self) { suggestion in
                                                Button {
                                                    if let idx = medications.firstIndex(where: { $0.id == line.id }) {
                                                        medications[idx].text = suggestion
                                                    }
                                                    medFocusID = nil
                                                } label: {
                                                    Text(suggestion)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.redmedDark)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .padding(.horizontal, 16).padding(.vertical, 9)
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
                        addButton("Add medication") { medications.append(DraftLine()) }
                    }

                    // CONDITIONS
                    editSectionLabel("Conditions")
                    editCard {
                        ForEach($conditions) { $line in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TextField("Condition", text: $line.text)
                                        .font(.system(size: 15))
                                        .foregroundColor(.redmedDark)
                                        .onChange(of: line.text) { _, _ in conditionFocusID = line.id }
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            conditions.removeAll { $0.id == line.id }
                                            if conditionFocusID == line.id { conditionFocusID = nil }
                                        }
                                    } label: {
                                        Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 13)

                                if conditionFocusID == line.id && !line.text.isEmpty {
                                    let matches = commonConditions.filter { $0.localizedCaseInsensitiveContains(line.text) }.prefix(5)
                                    if !matches.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(Array(matches), id: \.self) { suggestion in
                                                Button {
                                                    if let idx = conditions.firstIndex(where: { $0.id == line.id }) {
                                                        conditions[idx].text = suggestion
                                                    }
                                                    conditionFocusID = nil
                                                } label: {
                                                    Text(suggestion)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.redmedDark)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .padding(.horizontal, 16).padding(.vertical, 9)
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
                        addButton("Add condition") { conditions.append(DraftLine()) }
                    }

                    // CONTACTS
                    editSectionLabel("Emergency Contacts")
                    editCard {
                        ForEach($contacts) { $contact in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("Name", text: $contact.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.redmedDark)
                                    TextField("Relationship · phone", text: $contact.detail)
                                        .font(.system(size: 13))
                                        .foregroundColor(.redmedMuted)
                                }
                                Spacer()
                                Button {
                                    withAnimation { contacts.removeAll { $0.id == contact.id } }
                                } label: {
                                    Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
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
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
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
        profile.birthDate = birthDate
        profile.bloodType = bloodType
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
