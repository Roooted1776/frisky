import SwiftUI

/// Testing stub — no CoreNFC. Full implementation is parked in `NFCView.inactive.swift`.
/// Restore by copying that file over this one (see header in the inactive file).
struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @State private var showPublicCard = false
    @State private var showDisabledAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("NFC Bracelet")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.redmedDark)
                        Text("NFC is disabled for testing. The full implementation is saved as NFCView.inactive.swift.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        statusRow("NFC write / read parked — not linked to CoreNFC", showDivider: true)
                        statusRow(profile.braceletLinked ? "Bracelet marked linked from a prior session" : "Bracelet not linked", showDivider: false)
                    }
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.redmedDivider, lineWidth: 1))

                    sectionLabel("Set up")
                    VStack(spacing: 12) {
                        Button { showDisabledAlert = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wave.3.right")
                                Text("Write to NFC tag")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.redmedMuted.opacity(0.45))
                            .clipShape(Capsule())
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            syncBullet("NFC hardware flow is inactive while testing.")
                            syncBullet("Re-enable by restoring NFCView.inactive.swift over NFCView.swift.")
                        }
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))

                    sectionLabel("Verify")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview the emergency card UI without scanning a tag.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .lineSpacing(3)
                        SecondaryButton("Preview emergency card", icon: "doc.text") { showPublicCard = true }
                    }
                    .padding(14)
                    .background(Color.redmedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.redmedBg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("NFC Bracelet").font(.system(size: 17, weight: .semibold)).foregroundColor(.redmedDark)
                }
            }
            .sheet(isPresented: $showPublicCard) { PublicCardView(profile: profile) }
            .alert("NFC disabled", isPresented: $showDisabledAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("CoreNFC is parked in NFCView.inactive.swift for testing. Restore that file to activate write/read.")
            }
        }
    }

    @ViewBuilder
    func statusRow(_ text: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            if showDivider {
                Divider().overlay(Color.black.opacity(0.06))
            }
        }
    }

    @ViewBuilder
    func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.5)
            .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    func syncBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.redmedAccent)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedMuted)
                .lineSpacing(3)
        }
    }
}
