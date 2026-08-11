import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var birthDate = ""
    @State private var bloodType = ""
    @State private var allergies: [String] = []
    @State private var medications: [String] = []
    @State private var conditions: [String] = []
    @State private var contacts: [EmergencyContact] = []

    var body: some View {
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
                        ForEach($allergies, id: \.self) { $item in
                            HStack {
                                TextField("Allergy", text: $item)
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedDark)
                                Spacer()
                                Button { withAnimation { allergies.removeAll { $0 == item } } } label: {
                                    Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            Divider().padding(.leading, 16)
                        }
                        addButton("Add allergy") { allergies.append("") }
                    }

                    // MEDICATIONS
                    editSectionLabel("Medications")
                    editCard {
                        ForEach($medications, id: \.self) { $item in
                            HStack {
                                TextField("Medication", text: $item)
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedDark)
                                Spacer()
                                Button { withAnimation { medications.removeAll { $0 == item } } } label: {
                                    Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            Divider().padding(.leading, 16)
                        }
                        addButton("Add medication") { medications.append("") }
                    }

                    // CONDITIONS
                    editSectionLabel("Conditions")
                    editCard {
                        ForEach($conditions, id: \.self) { $item in
                            HStack {
                                TextField("Condition", text: $item)
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedDark)
                                Spacer()
                                Button { withAnimation { conditions.removeAll { $0 == item } } } label: {
                                    Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            Divider().padding(.leading, 16)
                        }
                        addButton("Add condition") { conditions.append("") }
                    }

                    // CONTACTS
                    editSectionLabel("Emergency Contacts")
                    editCard {
                        ForEach($contacts) { $contact in
                            if contact.id != contacts.first?.id {
                                Divider()
                            }
                            HStack(spacing: 0) {
                                Text("Name")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                                    .frame(width: 100, alignment: .leading)
                                    .padding(.trailing, 12)
                                TextField("Full name", text: $contact.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedDark)
                                    .textContentType(.name)
                                Button {
                                    withAnimation { contacts.removeAll { $0.id == contact.id } }
                                } label: {
                                    Text("✕").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                }
                                .padding(.leading, 10)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            Divider().padding(.leading, 128)
                            HStack(spacing: 0) {
                                Text("Phone")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                                    .frame(width: 100, alignment: .leading)
                                    .padding(.trailing, 12)
                                TextField("Phone number", text: $contact.phone)
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedDark)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            Divider().padding(.leading, 128)
                            HStack(spacing: 0) {
                                Text("Relationship")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                                    .frame(width: 100, alignment: .leading)
                                    .padding(.trailing, 12)
                                TextField("Optional", text: $contact.relationship)
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedDark)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                        }
                        if !contacts.isEmpty {
                            Divider()
                        }
                        addButton("Add contact") {
                            contacts.append(EmergencyContact(name: "", relationship: "", phone: ""))
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
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
        profile.name = name
        profile.birthDate = birthDate
        profile.bloodType = bloodType
        profile.allergies = allergies.filter { !$0.isEmpty }
        profile.medications = medications.filter { !$0.isEmpty }
        profile.conditions = conditions.filter { !$0.isEmpty }
        profile.contacts = contacts.compactMap { contact -> EmergencyContact? in
            let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let phone = contact.phone.trimmingCharacters(in: .whitespacesAndNewlines)
            let rel = contact.relationship.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty || !phone.isEmpty else { return nil }
            return EmergencyContact(name: name, relationship: rel, phone: phone)
        }
        dismiss()
    }
}
