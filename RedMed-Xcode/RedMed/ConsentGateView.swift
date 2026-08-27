import SwiftUI

/// Legal consent, shown every time after a successful Face ID unlock.
/// Never mounts in front of the lock shell (AGENTS.md: no extra pages before Face ID).
/// Never shown on passerby tapper. `ConsentGateView` is recreated (fresh
/// `@State`) on every unlock because it lives inside `OwnerAppLock`'s
/// `.unlocked` branch, which SwiftUI tears down and rebuilds on every
/// re-lock — so starting `hasAccepted` at `false` re-gates on every auth.
enum ConsentSettings {
    static let acceptedVersionKey = "redmed.consentAcceptedVersion"
    /// Bump with the Version line in Help.html Terms / Privacy / Security
    /// whenever a change is material enough to require re-consent.
    static let currentVersion = "4.1"

    /// Timestamp of the most recent acceptance — record-keeping only, not
    /// used to gate the screen (that always starts unaccepted per unlock).
    static func recordAcceptance() {
        UserDefaults.standard.set(currentVersion, forKey: acceptedVersionKey)
    }
}

struct ConsentGateView<Content: View>: View {
    @State private var hasAccepted = false
    @State private var checked = false
    @State private var showPolicy: HelpDocument.Policy?
    @ViewBuilder var content: () -> Content

    var body: some View {
        if hasAccepted {
            content()
        } else {
            gate
        }
    }

    private var gate: some View {
        ZStack {
            RedMedPageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LockMedGlyph(size: 64)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("RedMed is a local emergency medical ID and EMS assist. It is not a medical device, does not provide medical advice, and does not promise any medical outcome. Always call 911 first in a real emergency.")
                        Text("Your profile stays on this iPhone, and on a band if you write one — RedMed runs no server for it. Read the full Terms, Privacy, and Security pages below before continuing.")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .padding(12)
                    .redmedBox()

                    VStack(spacing: 0) {
                        ForEach(HelpDocument.Policy.allCases) { policy in
                            if policy != .guide {
                                Divider().padding(.leading, 16)
                            }
                            Button {
                                showPolicy = policy
                            } label: {
                                HStack {
                                    Text(policy.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.redmedDark)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.redmedMuted.opacity(0.55))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .redmedBox()

                    Button {
                        RedMedHaptics.light()
                        checked.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: checked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(checked ? .redmedAccent : .redmedMuted)
                            Text("I have read and agree to the RedMed Terms, Privacy, and Security pages, including the medical-device disclaimer, liability limits, and binding arbitration / class-action waiver in Terms.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.redmedDark)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(checked ? [.isButton, .isSelected] : .isButton)

                    PrimaryButton(title: "Agree and continue", disabled: !checked) {
                        ConsentSettings.recordAcceptance()
                        RedMedHaptics.success()
                        // No spring into Main — that animation kept cream on
                        // screen after Face ID while the tab tree mounted.
                        var t = Transaction()
                        t.animation = nil
                        withTransaction(t) {
                            hasAccepted = true
                        }
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
            }
        }
        .sheet(item: $showPolicy) { policy in
            NavigationStack {
                LocalWebView(filename: HelpDocument.bundledFile, fragment: policy.fragment)
                    .navigationTitle(policy.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showPolicy = nil }
                        }
                    }
            }
        }
    }
}
