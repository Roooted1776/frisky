import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.dismiss) var dismiss
    @Environment(\.isScannerSession) private var isScannerSession

    @State private var name = ""
    @State private var birthDate = ""
    @State private var bloodType = ""
    @State private var allergies: [String] = []
    @State private var allergyFocusIndex: Int? = nil
    @State private var medications: [String] = []
    @State private var medFocusIndex: Int? = nil
    @State private var conditions: [String] = []
    @State private var conditionFocusIndex: Int? = nil
    @State private var contacts: [EmergencyContact] = []

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
                Text("Edit Profile")
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
                        ForEach($allergies.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TextField("Allergy", text: $allergies[i])
                                        .font(.system(size: 15))
                                        .foregroundColor(.redmedDark)
                                        .onChange(of: allergies[i]) { allergyFocusIndex = i }
                                    Spacer()
                                    Button { withAnimation { _ = allergies.remove(at: i) } } label: {
                                        Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 13)

                                if allergyFocusIndex == i && !allergies[i].isEmpty {
                                    let matches = commonAllergies.filter { $0.localizedCaseInsensitiveContains(allergies[i]) }.prefix(5)
                                    if !matches.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(Array(matches), id: \.self) { suggestion in
                                                Button {
                                                    allergies[i] = suggestion
                                                    allergyFocusIndex = nil
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
                        addButton("Add allergy") { allergies.append("") }
                    }

                    // MEDICATIONS
                    editSectionLabel("Medications")
                    editCard {
                        ForEach($medications.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TextField("Medication", text: $medications[i])
                                        .font(.system(size: 15))
                                        .foregroundColor(.redmedDark)
                                        .onChange(of: medications[i]) { medFocusIndex = i }
                                    Spacer()
                                    Button { withAnimation { _ = medications.remove(at: i) } } label: {
                                        Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 13)

                                if medFocusIndex == i && !medications[i].isEmpty {
                                    let matches = commonMedications.filter { $0.localizedCaseInsensitiveContains(medications[i]) }.prefix(5)
                                    if !matches.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(Array(matches), id: \.self) { suggestion in
                                                Button {
                                                    medications[i] = suggestion
                                                    medFocusIndex = nil
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
                        addButton("Add medication") { medications.append("") }
                    }

                    // CONDITIONS
                    editSectionLabel("Conditions")
                    editCard {
                        ForEach($conditions.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TextField("Condition", text: $conditions[i])
                                        .font(.system(size: 15))
                                        .foregroundColor(.redmedDark)
                                        .onChange(of: conditions[i]) { conditionFocusIndex = i }
                                    Spacer()
                                    Button { withAnimation { _ = conditions.remove(at: i) } } label: {
                                        Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 13)

                                if conditionFocusIndex == i && !conditions[i].isEmpty {
                                    let matches = commonConditions.filter { $0.localizedCaseInsensitiveContains(conditions[i]) }.prefix(5)
                                    if !matches.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(Array(matches), id: \.self) { suggestion in
                                                Button {
                                                    conditions[i] = suggestion
                                                    conditionFocusIndex = nil
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
                        addButton("Add condition") { conditions.append("") }
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
        allergies = profile.allergies
        medications = profile.medications
        conditions = profile.conditions
        contacts = profile.contacts
    }

    private func save() {
        guard !isScannerSession else {
            dismiss()
            return
        }
        profile.name = name
        profile.birthDate = birthDate
        profile.bloodType = bloodType
        profile.allergies = allergies.filter { !$0.isEmpty }
        profile.medications = medications.filter { !$0.isEmpty }
        profile.conditions = conditions.filter { !$0.isEmpty }
        profile.contacts = contacts.filter { !$0.name.isEmpty }
        dismiss()
    }
}
