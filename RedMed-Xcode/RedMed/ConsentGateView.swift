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
    @State private var selectedPolicy: HelpDocument.Policy = .privacy
    @State private var openPolicy: HelpDocument.Policy?
    /// OwnerAppLock already did Face ID. This view is only the acknowledgment.
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
                gate
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
                        Text("Your profile stays on this iPhone, and on a band if you write one — RedMed runs no server for it. Privacy, Security, Terms, and the Medical disclaimer are in the block below.")
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
                        policyTabs
                        Divider().overlay(Color.redmedDivider)
                        LocalWebView(filename: HelpDocument.bundledFile, fragment: selectedPolicy.fragment)
                            .frame(maxWidth: .infinity)
                            .frame(height: 440)
                            .accessibilityLabel(selectedPolicy.title)
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

    /// Privacy / Security / Terms / Medical disclaimer — same selected-tab
    /// tint as the dock. Four labels wrap to two rows so each stays readable.
    /// Tapping a title selects it and shows that Help.html section on this
    /// page. Tapping the already-selected title still opens the full sheet.
    private var policyTabs: some View {
        let columns = [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6)
        ]
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(HelpDocument.Policy.allCases) { policy in
                let isOn = selectedPolicy == policy
                Button {
                    RedMedHaptics.selection()
                    if isOn {
                        openPolicy = policy
                    } else {
                        selectedPolicy = policy
                    }
                } label: {
                    Text(policy.title)
                        .font(.system(size: RedMedChrome.rowFont, weight: isOn ? .semibold : .medium))
                        .foregroundColor(isOn ? .redmedAccent : .redmedMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: RedMedChrome.chipRadius, style: .continuous)
                                .fill(isOn ? Color.redmedAccent.opacity(0.12) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(RedMedPressStyle(scale: 0.98, haptic: nil))
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                .accessibilityHint(isOn ? "Shows \(policy.title) below. Tap again for full page." : "Show \(policy.title)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
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
