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
    @State private var openPolicy: HelpDocument.Policy?
    @AppStorage(RedMedHaptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @ObservedObject private var locationSuggester = LocationAccessSuggester.shared
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
                    Text("Before you continue")
                        .font(.system(size: 22, weight: .bold))
                        .kerning(-0.4)
                        .foregroundColor(.redmedDark)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("RedMed is a personal medical ID and first-aid reference on this iPhone. It is not a medical device, does not diagnose or treat, and does not replace emergency dispatch. Always call emergency services first in a real emergency.")
                        Text("Your profile stays on this iPhone, and on a band if you write one — RedMed runs no server for it. Privacy, Security, and Terms are in the block below.")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .padding(14)
                    .redmedBox()

                    VStack(spacing: 0) {
                        Toggle("Haptic feedback", isOn: $hapticsEnabled)
                            .font(.system(size: RedMedChrome.rowFont, weight: .medium))
                            .tint(.redmedAccent)
                            .padding(.horizontal, RedMedChrome.pagePadX)
                            .padding(.vertical, RedMedChrome.rowVPad)
                        Divider().overlay(Color.redmedDivider).padding(.leading, RedMedChrome.pagePadX)
                        Toggle("Location", isOn: $locationEnabled)
                            .font(.system(size: RedMedChrome.rowFont, weight: .medium))
                            .tint(.redmedAccent)
                            .padding(.horizontal, RedMedChrome.pagePadX)
                            .padding(.vertical, RedMedChrome.rowVPad)
                            .onChange(of: locationEnabled) { _, on in
                                // Pref only — never call requestWhenInUseAuthorization here.
                                // Find Help prompts the system sheet once when GPS is actually needed.
                                if on { locationSuggester.refresh() }
                            }
                        if locationEnabled && locationSuggester.mustOpenSettings {
                            Divider().overlay(Color.redmedDivider).padding(.leading, RedMedChrome.pagePadX)
                            Button("Open iOS Location Settings") {
                                locationSuggester.openSettings()
                            }
                            .font(.system(size: RedMedChrome.rowFont, weight: .medium))
                            .foregroundColor(.redmedAccent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, RedMedChrome.pagePadX)
                            .padding(.vertical, RedMedChrome.rowVPad)
                        }
                    }
                    // flatten: false — these Toggles are live-editing content;
                    // `.drawingGroup()` (redmedBox's flattened default) can
                    // leave a Toggle inside it visible but unresponsive to
                    // taps (see redmedBox's doc comment in Theme.swift).
                    .redmedBox(flatten: false)
                    Text("Location defaults on. No RedMed popup — iOS may ask Allow once the first time Find Help needs GPS (Apple requires that tap). Siren / max volume / brightness arm on crash or SOS only while this app is open — not Apple Crash Detection, and not a background dispatch service.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(HelpDocument.Policy.allCases.enumerated()), id: \.element.id) { index, policy in
                            if index > 0 {
                                Divider().overlay(Color.redmedDivider).padding(.leading, RedMedChrome.pagePadX)
                            }
                            policyRow(policy)
                        }
                    }
                    .redmedBox(flatten: false)

                    Button {
                        RedMedHaptics.light()
                        checked.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: checked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 22))
                                .foregroundColor(checked ? .redmedAccent : .redmedMuted)
                            Text("I have read and agree to the RedMed Terms, Privacy, and Security pages, including the medical-device disclaimer, liability limits, and binding arbitration / class-action waiver in Terms.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.redmedDark)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RedMedPressStyle(scale: 0.99, haptic: nil))
                    .accessibilityAddTraits(checked ? [.isButton, .isSelected] : .isButton)

                    PrimaryButton(title: "Agree and continue", disabled: !checked) {
                        ConsentSettings.recordAcceptance()
                        RedMedHaptics.success()
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
        .onAppear {
            guard locationEnabled else { return }
            // Status read is cheap (no CLLocationManager), but still hop
            // off the first consent paint so Face ID → Before you continue
            // is not fighting a locationd ping.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard locationEnabled else { return }
                locationSuggester.refresh()
            }
        }
        .sheet(item: $openPolicy) { policy in
            ConsentPolicySheet(policy: policy)
                .presentationBackground(Color.redmedBg)
        }
    }

    /// One policy link row (title + chevron.right). Tapping opens the real
    /// Help.html section for that policy in a sheet — keeps this screen a
    /// short, clean acknowledgment instead of a second copy of Help's text.
    @ViewBuilder
    private func policyRow(_ policy: HelpDocument.Policy) -> some View {
        Button {
            RedMedHaptics.light()
            openPolicy = policy
        } label: {
            HStack {
                Text(policy.title)
                    .font(.system(size: RedMedChrome.rowFont, weight: .semibold))
                    .foregroundColor(.redmedDark)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.redmedMuted.opacity(0.55))
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.vertical, RedMedChrome.rowVPad)
            .contentShape(Rectangle())
        }
        .buttonStyle(RedMedPressStyle(scale: 0.99, haptic: nil))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens \(policy.title)")
    }
}

private struct ConsentPolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    let policy: HelpDocument.Policy

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OwnerModalChrome(
                    title: policy.title,
                    leadingTitle: "Done",
                    leadingAction: { dismiss() }
                )
                LocalWebView(filename: HelpDocument.bundledFile, fragment: policy.fragment)
            }
            .background { RedMedPageBackground() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
