import SwiftUI

struct MyIDView: View {
    @EnvironmentObject var profile: ProfileData
    @Binding var tab: AppTab
    @State private var showEdit = false
    @State private var showAuthFailedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header — icon, name/bracelet link, Edit
            HStack(alignment: .top, spacing: 10) {
                Image("BrandLogo")
                    .resizable().frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.redmedAccent.opacity(0.15), radius: 5, y: 3)

                if profile.hasData {
                    Button { tab = .nfc } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(profile.name)'s iPhone")
                                .font(.system(size: 20, weight: .bold)).foregroundColor(.redmedDark)
                            Text(profile.braceletLinked ? "LINKED BRACELET ›" : "PAIR BLANK BRACELET ›")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.redmedAccent.opacity(0.85))
                                .kerning(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Set up your ID")
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.redmedDark)
                }

                Spacer()

                Button("Edit") { requestEdit() }
                    .font(.system(size: 17))
                    .foregroundColor(.redmedAccent)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !profile.hasData {
                        HStack(spacing: 0) {
                            Text("Tap ").font(.system(size: 14, weight: .medium)).foregroundColor(.redmedMuted)
                            Text("Edit").font(.system(size: 14, weight: .bold)).foregroundColor(.redmedAccent)
                            Text(" to add your name, then pair a blank bracelet.")
                                .font(.system(size: 14, weight: .medium)).foregroundColor(.redmedMuted)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 8)
                    } else if !profile.braceletLinked {
                        Button { tab = .nfc } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "wave.3.right")
                                    .font(.system(size: 16, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pair your blank bracelet")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("My ID → NFC → Write to NFC tag")
                                        .font(.system(size: 12, weight: .medium))
                                        .opacity(0.85)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(14)
                            .background(
                                LinearGradient(colors: [Color(red:1, green:0.447, blue:0.537), .redmedAccent],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }

                    // YOU
                    Group {
                        SectionLabel(text: "You").padding(.horizontal, 16).padding(.top, 2)
                        cardGroup {
                            profileRow(label: "Name", value: profile.name)
                            Divider().padding(.leading, 16)
                            profileRow(label: "Birth date", value: profile.birthDate)
                            Divider().padding(.leading, 16)
                            profileRow(label: "Blood type", value: profile.bloodType)
                        }
                    }

                    listSection(title: "Allergies", items: profile.allergies)
                    listSection(title: "Medications", items: profile.medications)
                    listSection(title: "Conditions", items: profile.conditions)

                    // CONTACTS
                    SectionLabel(text: "Contacts").padding(.horizontal, 16).padding(.top, 12)
                    cardGroup {
                        if profile.contacts.isEmpty {
                            emptyRow()
                        } else {
                            ForEach(profile.contacts) { c in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name)
                                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.redmedDark)
                                    Text(c.detail)
                                        .font(.system(size: 12, weight: .medium)).foregroundColor(.redmedMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 11)
                                if c.id != profile.contacts.last?.id { Divider().padding(.leading, 16) }
                            }
                        }
                    }

                    Spacer(minLength: 24)
                }
            }
            .background(Color.redmedBg)
        }
        .fullScreenCover(isPresented: $showEdit) { EditProfileView().environmentObject(profile) }
        .alert("Authentication Failed", isPresented: $showAuthFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or passcode is required to edit your medical profile.")
        }
    }

    private func requestEdit() {
        guard profile.hasData else {
            showEdit = true
            return
        }
        BiometricAuth.authenticate(reason: "Authenticate to edit your medical profile.") { success in
            if success {
                showEdit = true
            } else {
                showAuthFailedAlert = true
            }
        }
    }

    @ViewBuilder
    func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundColor(.redmedMuted)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(value.isEmpty ? Color.redmedMuted.opacity(0.4) : .redmedDark)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    @ViewBuilder
    func emptyRow() -> some View {
        Text("—").font(.system(size: 14)).foregroundColor(Color.redmedMuted.opacity(0.4))
            .padding(.horizontal, 16).padding(.vertical, 11)
    }

    @ViewBuilder
    func cardGroup<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.redmedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.redmedDivider, lineWidth: 1))
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    func listSection(title: String, items: [String]) -> some View {
        SectionLabel(text: title).padding(.horizontal, 16).padding(.top, 12)
        cardGroup {
            if items.isEmpty { emptyRow() }
            else {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Text(item).font(.system(size: 14)).foregroundColor(.redmedDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                    if i < items.count - 1 { Divider().padding(.leading, 16) }
                }
            }
        }
    }
}


