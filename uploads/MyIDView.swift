import SwiftUI

struct MyIDView: View {
    @EnvironmentObject var profile: ProfileData
    @Binding var tab: AppTab
    @State private var showEdit = false
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            ZStack {
                HStack {
                    Spacer()
                    if profile.hasData == false {
                        // No edit button shown on empty state — just logo
                    }
                }
                HStack {
                    Image("wordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 22)
                    Spacer()
                    Button("Edit") { showEdit = true }
                        .font(.system(size: 17))
                        .foregroundColor(.redmedAccent)
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 44)
            .background(Color.white.opacity(0.9))
            .overlay(alignment: .bottom) { Divider().overlay(Color.redmedDark.opacity(0.08)) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    if !profile.hasData {
                        HStack(spacing: 0) {
                            Text("Tap ").font(.system(size: 14, weight: .medium)).foregroundColor(.redmedMuted)
                            Text("Edit").font(.system(size: 14, weight: .bold)).foregroundColor(.redmedAccent)
                            Text(" to add your name and set up your bracelet.")
                                .font(.system(size: 14, weight: .medium)).foregroundColor(.redmedMuted)
                        }
                        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
                    } else {
                        Button { tab = .nfc } label: {
                            HStack(spacing: 10) {
                                Image("BrandLogo")
                                    .resizable().frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 13))
                                    .shadow(color: Color.redmedAccent.opacity(0.15), radius: 5, y: 3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(profile.name)'s iPhone")
                                        .font(.system(size: 22, weight: .bold)).foregroundColor(.redmedDark)
                                    Text("LINKED BRACELET ›")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color.redmedAccent.opacity(0.85))
                                        .kerning(0.7)
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
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
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(c.name.isEmpty ? "Emergency contact" : c.name)
                                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.redmedDark)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if !c.phone.isEmpty {
                                            Text(c.phone)
                                                .font(.system(size: 12, weight: .medium)).foregroundColor(.redmedAccent)
                                                .multilineTextAlignment(.trailing)
                                        }
                                    }
                                    if !c.relationship.isEmpty {
                                        Text(c.relationship)
                                            .font(.system(size: 12, weight: .medium)).foregroundColor(.redmedMuted)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 11)
                                if c.id != profile.contacts.last?.id { Divider().padding(.leading, 16) }
                            }
                        }
                    }

                    // QUICK ACTIONS
                    HStack(spacing: 0) {
                        Button { tab = .nfc } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "wave.3.right.circle").font(.system(size: 18)).foregroundColor(.redmedAccent)
                                Text("Bracelet").font(.system(size: 12, weight: .semibold)).foregroundColor(.redmedAccent)
                            }.padding(.horizontal, 10).padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        Divider().frame(height: 28)
                        Button { showHelp = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle").font(.system(size: 18)).foregroundColor(.redmedMuted)
                                Text("How it works").font(.system(size: 12, weight: .semibold)).foregroundColor(.redmedMuted)
                            }.padding(.horizontal, 10).padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 14).padding(.bottom, 4)

                    Text(""Control your fear. Control the moment. You have what it takes to save a life."")
                        .font(.system(size: 11)).italic().foregroundColor(.redmedDark)
                        .multilineTextAlignment(.center).lineSpacing(4)
                        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
                }
            }
            .background(Color.redmedBg)
        }
        .sheet(isPresented: $showEdit) { EditProfileView().environmentObject(profile) }
        .sheet(isPresented: $showHelp) { HelpMenuView() }
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

struct HelpMenuView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Privacy Policy") { Text("Privacy Policy").padding() }
                NavigationLink("Terms of Service") { Text("Terms of Service").padding() }
                NavigationLink("How It Works") { Text("How It Works").padding() }
                NavigationLink("Security") { Text("Security").padding() }
            }
            .navigationTitle("Policies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.redmedAccent)
                }
            }
        }
    }
}
