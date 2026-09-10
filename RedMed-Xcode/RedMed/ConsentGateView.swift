import SwiftUI
import UIKit

/// Legal consent. First launch (or after a material policy version bump)
/// only — stored version skips Before You Continue on later cold starts.
/// Agree + checkbox only; no Face ID on that page. Agree covers location
/// and motion while the app is open. Face ID runs on cream (Retry until
/// success) while Main warms underneath — once after Agree, and again on
/// every cold re-entry after acknowledge — then iOS When-In-Use once when
/// still `.notDetermined`, then Main is interactive.
/// Same-session background → foreground does **not** re-prompt (no
/// OwnerAppLock relock). Edit / Save / Erase / Load From Band still Face ID.
/// Never on passerby tapper or in-app band / UL tap card (`BandTapIngress`).
enum ConsentSettings {
    static let acceptedVersionKey = "redmed.consentAcceptedVersion"
    static let currentVersion = "4.14"

    static var hasAcceptedCurrent: Bool {
        UserDefaults.standard.string(forKey: acceptedVersionKey) == currentVersion
    }

    static func recordAcceptance() {
        UserDefaults.standard.set(currentVersion, forKey: acceptedVersionKey)
    }

    /// After Erase all data — next open shows Before you continue.
    static func clearAcceptance() {
        UserDefaults.standard.removeObject(forKey: acceptedVersionKey)
    }
}

struct ConsentGateView<Content: View>: View {
    /// Agree already stored when this gate was created — skip Before You
    /// Continue, warm Main under Face ID cream. Fresh / Erase / policy bump
    /// starts at the gate. Captured at init (not a static) so Agree → Face ID
    /// in the same process still labels as post-Agree, not returning.
    private let consentedAtLaunch = ConsentSettings.hasAcceptedCurrent

    /// Hit-testing unlocked only after Face ID succeeds this process.
    @State private var hasAccepted = false
    /// Arm Main under the Face ID cream so success is not a cold tab mount.
    @State private var contentArmed = ConsentSettings.hasAcceptedCurrent
    /// True until Face ID succeeds (Agree path, or returning cold re-entry).
    @State private var awaitingPostAgreeFaceID = ConsentSettings.hasAcceptedCurrent
    @State private var isAuthenticating = false
    @State private var didAutoPrompt = false
    @State private var showRetry = false
    @State private var biometryFailed = false
    @State private var notInteractive = false
    @State private var unavailableReason: BiometricAuth.UnavailableReason?
    @State private var checked = false
    /// Which policy section the ack sheet opens — one link per document.
    @State private var openPolicy: HelpDocument.Policy? = nil
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var profile: ProfileData
    @EnvironmentObject private var bandTap: BandTapIngress
    @AppStorage(RedMedHaptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            if contentArmed {
                content()
                    .accessibilityHidden(!hasAccepted)
                    .allowsHitTesting(hasAccepted)
            }
            // Hide owner start screens while an ungated band tap card is up.
            if !bandTap.isPresentingTapCard {
                if awaitingPostAgreeFaceID {
                    postAgreeFaceIDPane
                } else if !hasAccepted {
                    gate
                }
            }
        }
        .onAppear {
            SnapshotSafeCover.shared.reveal()
            tryPromptPostAgreeFaceID()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeKeyNotification)) { _ in
            tryPromptPostAgreeFaceID()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                tryPromptPostAgreeFaceID()
            }
        }
        .onChange(of: bandTap.session?.id) { _, newId in
            let presenting = newId != nil
            if presenting {
                // Tap card wins — cancel any Face ID sheet mid-flight.
                _ = BiometricAuth.cancelInFlight()
                isAuthenticating = false
                didAutoPrompt = false
                showRetry = false
                biometryFailed = false
                notInteractive = false
                unavailableReason = nil
            } else {
                // Card dismissed — resume owner cold-open Face ID if still needed.
                tryPromptPostAgreeFaceID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedDidEraseLocalData)) { _ in
            returnToAcknowledgment()
        }
    }

    private func returnToAcknowledgment() {
        checked = false
        openPolicy = nil
        awaitingPostAgreeFaceID = false
        isAuthenticating = false
        didAutoPrompt = false
        showRetry = false
        biometryFailed = false
        notInteractive = false
        unavailableReason = nil
        PolicyWebViewPool.discard()
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            hasAccepted = false
            contentArmed = false
        }
    }

    /// Flat cream while Face ID runs after Agree — no second Before You Continue,
    /// no Face ID icon blocking Agree, no Proceed chrome unless retry/cancel.
    private var postAgreeFaceIDPane: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            if let unavailableReason {
                Text(unavailableReason.message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, RedMedChrome.pagePadX)
                PrimaryButton(title: "Open Settings", flatten: false) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
            } else if showRetry {
                if biometryFailed {
                    Text("Couldn't verify it's you. Try again.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, RedMedChrome.pagePadX)
                } else if notInteractive {
                    Text("Couldn't open Face ID. Try again.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, RedMedChrome.pagePadX)
                }
                PrimaryButton(title: "Retry Face ID", flatten: false) {
                    didAutoPrompt = false
                    showRetry = false
                    runPostAgreeFaceID()
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
            }
            // While authenticating: empty cream — system Face ID sheet is the UI.
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { RedMedPageBackground() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Confirm with Face ID to open RedMed")
    }

    private var gate: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Before You Continue")
                        .font(.system(size: 22, weight: .bold))
                        .kerning(-0.4)
                        .foregroundColor(.redmedDark)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("RedMed is a personal medical ID and first-aid reference on this iPhone. It is not a medical device, does not diagnose or treat, and does not replace emergency dispatch. Always call emergency services first in a real emergency.")
                        Text("Your profile stays on this iPhone, and on a band if you write one — RedMed runs no server for it.")
                        Text("Agree covers location and motion while RedMed is open — Find Help GPS and crash detection. GPS stops when you leave or close the app. Never sent to us. iOS may ask Allow once after Face ID so 911 is not blocked later.")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .padding(14)
                    // Static copy — flatten for cheaper first ack paint.
                    .redmedBox(flatten: true)

                    VStack(spacing: 0) {
                        Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                            .font(.system(size: RedMedChrome.rowFont, weight: .medium))
                            .tint(.redmedAccent)
                            .padding(.horizontal, RedMedChrome.pagePadX)
                            .padding(.vertical, RedMedChrome.rowVPad)
                    }
                    // Live Toggle — flatten:false so compositingGroup cannot eat taps.
                    .redmedBox(flatten: false)

                    VStack(spacing: 0) {
                        ForEach(Array(HelpDocument.Policy.allCases.enumerated()), id: \.element.id) { index, policy in
                            if index > 0 {
                                Divider().overlay(Color.redmedDivider)
                            }
                            Button {
                                RedMedHaptics.light()
                                openPolicy = policy
                            } label: {
                                HelpPolicyRowLabel(policy: policy, titleWeight: .semibold)
                            }
                            .buttonStyle(RedMedPressStyle(scale: 0.99, haptic: nil))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(policy.title)
                            .accessibilityHint("Opens \(policy.title)")
                        }
                    }
                    .redmedBox(flatten: true)
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.bottom, 12)
            }

            VStack(spacing: 12) {
                Button {
                    RedMedHaptics.light()
                    checked.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundColor(checked ? .redmedAccent : .redmedMuted)
                        Text("I have read and agree to the RedMed Policies document (Privacy, Security, Terms, Medical Disclaimer, and Ships When Ready), including the medical-device disclaimer, liability limits, and binding arbitration / class-action waiver in Terms. Agree includes using location and motion on this iPhone while RedMed is open.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.redmedDark)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RedMedPressStyle(scale: 0.99, haptic: nil))
                .accessibilityAddTraits(checked ? [.isButton, .isSelected] : .isButton)

                PrimaryButton(title: "Agree And Continue", flatten: false) {
                    guard checked else { return }
                    enterApp()
                }
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(Color.redmedBg)
        }
        .background { RedMedPageBackground() }
        .task {
            // Defer Document.html WK warm past cream drop + first ack layout.
            // Immediate warm on appear fought LaunchRoot's one-yield cream
            // drop and spawned UIKit "keyboard was not even present" noise
            // from an off-screen WKWebView. Ack reading time is longer than
            // 500ms — a policy link still opens warm. Discarded on Agree.
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            PolicyWebViewPool.warm()
            RedMedSignpost.coldMark("policy WK warm started")
        }
        .sheet(item: $openPolicy, onDismiss: {
            // Sheet take() emptied the pool — warm again for a second open.
            PolicyWebViewPool.warm()
        }) { policy in
            ConsentPolicySheet(policy: policy)
                .presentationBackground(Color.redmedBg)
        }
    }

    /// Record acceptance on Agree, dismiss ack UI, then Face ID before Main.
    private func enterApp() {
        checked = true
        locationEnabled = true
        ConsentSettings.recordAcceptance()
        RedMedHaptics.success()
        SnapshotSafeCover.shared.reveal()
        openPolicy = nil
        // Drop the policy spare before Face ID / Main — do not keep a
        // WKWebView alive into the post-Agree path (same race class as the
        // old Agree-turn passerby shell warm).
        PolicyWebViewPool.discard()
        didAutoPrompt = false
        showRetry = false
        biometryFailed = false
        notInteractive = false
        unavailableReason = nil
        isAuthenticating = false
        // Policy-bump path deferred MainActor Keychain adopt until Agree —
        // kick it now so Face ID cream races a filled YOU (not under ack).
        profile.beginLaunchPrefetch()
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            // Arm Main under the Face ID cream so success reveals a warm tab
            // tree instead of a cold mount. Hit-testing stays off until auth.
            hasAccepted = false
            contentArmed = true
            awaitingPostAgreeFaceID = true
        }
        // Location is on as part of Agree. Do not fire iOS When-In-Use
        // here — it would stack with Face ID. After Face ID, request
        // When-In-Use so 911 is not blocked later. GPS still starts on
        // Find Help. Do not spawn a spare WKWebView on this turn — that
        // raced the owner RedMed embed and made tabs feel laggy after Agree.
        // NFCView warms the preview shell after that tab is first opened.
        tryPromptPostAgreeFaceID()
    }

    private func armMainAfterFaceID() {
        RedMedHaptics.success()
        SnapshotSafeCover.shared.reveal()
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            awaitingPostAgreeFaceID = false
            contentArmed = true
            hasAccepted = true
        }
        let readyLabel = consentedAtLaunch
            ? "returning cold Face ID"
            : "post-Agree Face ID"
        RedMedSignpost.coldLaunchMainReady(readyLabel)
        Task { @MainActor in
            // Parked LAContext can finish a leftover biometry ACL migrate
            // without a second sheet — restore may have raced Face ID.
            await profile.reloadAfterOwnerFaceID()
            await Task.yield()
            LocationAccessSuggester.shared.requestWhenInUseIfNeeded()
            RedMedSignpost.coldMark("When-In-Use requested (if needed)")
        }
    }

    private func tryPromptPostAgreeFaceID() {
        // Band / UL tap card is ungated — never stack Face ID under it.
        guard !bandTap.isPresentingTapCard else { return }
        guard awaitingPostAgreeFaceID, !hasAccepted, !didAutoPrompt, !isAuthenticating else { return }
        guard scenePhase != .background else { return }
        #if !targetEnvironment(simulator)
        guard BiometricAuth.hasKeyWindow else { return }
        #endif
        didAutoPrompt = true
        runPostAgreeFaceID()
    }

    private func runPostAgreeFaceID() {
        guard !bandTap.isPresentingTapCard else { return }
        guard awaitingPostAgreeFaceID, !hasAccepted, !isAuthenticating else { return }
        isAuthenticating = true
        biometryFailed = false
        notInteractive = false
        unavailableReason = nil
        showRetry = false
        RedMedSignpost.coldMark("post-Agree Face ID evaluate start")
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to open RedMed.",
            force: true,
            allowPasscode: true
        ) { outcome in
            Task { @MainActor in
                isAuthenticating = false
                // Band tap card is ungated — ignore Face ID results while it is up.
                if bandTap.isPresentingTapCard {
                    didAutoPrompt = false
                    return
                }
                let label: String = {
                    switch outcome {
                    case .success: return "success"
                    case .notVerified: return "notVerified"
                    case .declined: return "declined"
                    case .notInteractive: return "notInteractive"
                    case .timedOut: return "timedOut"
                    case .unavailable(let reason): return "unavailable(\(reason))"
                    }
                }()
                RedMedSignpost.coldMark("post-Agree Face ID → \(label)")
                switch outcome {
                case .success:
                    armMainAfterFaceID()
                case .notVerified:
                    biometryFailed = true
                    showRetry = true
                case .unavailable(let reason):
                    unavailableReason = reason
                    showRetry = true
                case .declined, .notInteractive, .timedOut:
                    notInteractive = (outcome == .notInteractive)
                    showRetry = true
                }
            }
        }
    }

}

private struct ConsentPolicySheet: View {
    let policy: HelpDocument.Policy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // No NavigationStack — OwnerModalChrome is the only chrome. Skipping
        // the stack avoids an extra layout pass before the warmed WKWebView
        // appears. Title matches the ack row that opened this sheet.
        HelpPolicyPage(
            startAt: policy,
            showsDoneChrome: true,
            onDone: { dismiss() },
            pageTitle: policy.markedTitle
        )
    }
}
