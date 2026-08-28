import SwiftUI

/// Legal consent after Face ID. First launch (or after a material policy
/// version bump) only — re-showing it on every unlock was hangtime cream
/// between lock and Main. Never in front of the lock shell. Never on
/// passerby tapper.
enum ConsentSettings {
    static let acceptedVersionKey = "redmed.consentAcceptedVersion"
    /// Bump with the Version line in Help.html Terms / Privacy / Security
    /// whenever a change is material enough to require re-consent.
    static let currentVersion = "4.1"

    static var hasAcceptedCurrent: Bool {
        UserDefaults.standard.string(forKey: acceptedVersionKey) == currentVersion
    }

    static func recordAcceptance() {
        UserDefaults.standard.set(currentVersion, forKey: acceptedVersionKey)
    }
}

struct ConsentGateView<Content: View>: View {
    @State private var hasAccepted = ConsentSettings.hasAcceptedCurrent
    /// First launch keeps Main off until the gate has painted. Arm after
    /// Task.yield so Agree is a cover-drop, not a cold WKWebView first paint.
    @State private var contentArmed = ConsentSettings.hasAcceptedCurrent
    @State private var checked = false
    @State private var openPolicy: HelpDocument.Policy?
    /// Face ID on this page first. Simulator auto-succeeds in BiometricAuth
    /// so the ack is the first real frame. Device shows the heart + title
    /// under the system sheet, then the acknowledgment.
    @State private var faceUnlocked = false
    @State private var faceIDStarted = false
    @AppStorage(RedMedHaptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @ObservedObject private var locationSuggester = LocationAccessSuggester.shared
    @ViewBuilder var content: () -> Content

    var body: some View {
        // Page 1 (this gate) must paint first. Then arm Main underneath so
        // Agree is a cover-drop, not a cold first paint of WKWebView / tabs.
        ZStack {
            if contentArmed {
                content()
                    .accessibilityHidden(!hasAccepted)
                    .allowsHitTesting(hasAccepted)
            }
            if !hasAccepted {
                if faceUnlocked {
                    gate
                } else {
                    facePrompt
                }
            }
        }
        .onAppear {
            guard !contentArmed else { return }
            Task { @MainActor in
                await Task.yield()
                contentArmed = true
            }
        }
    }

    /// Face ID theme on Before you continue — not a blank cream hang.
    private var facePrompt: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()
            VStack(spacing: 14) {
                LockMedGlyph(size: RedMedChrome.unlockFrameSize)
                Text("Before you continue")
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.4)
                    .foregroundColor(.redmedDark)
                    .multilineTextAlignment(.center)
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: startFaceID)
    }

    private func startFaceID() {
        guard !faceIDStarted, !faceUnlocked else { return }
        faceIDStarted = true
        BiometricAuth.authenticate(
            reason: "Continue with RedMed",
            force: true,
            allowPasscode: true
        ) { _ in
            // Never trap first launch on this shell. Cancel / fail still
            // opens the acknowledgment so Agree can enter the app. Later
            // cold starts use OwnerAppLock for PHI.
            var t = Transaction()
            t.animation = nil
            withTransaction(t) {
                faceUnlocked = true
            }
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
                    .redmedBox(flatten: false)

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

                    PrimaryButton(title: "Agree and continue", flatten: false) {
                        // One tap — the pink button looked tappable while
                        // disabled behind the checkbox, so Agree did nothing.
                        checked = true
                        ConsentSettings.recordAcceptance()
                        RedMedHaptics.success()
                        var t = Transaction()
                        t.animation = nil
                        withTransaction(t) {
                            contentArmed = true
                            hasAccepted = true
                        }
                        // NFC Preview pool — after page 2 is already on screen.
                        // Warming it on unlock raced RedMed's first paint.
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            PasserbyWebViewPool.warmFullShell()
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
