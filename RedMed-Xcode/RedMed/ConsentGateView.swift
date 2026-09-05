import SwiftUI
import UIKit

/// Legal consent. First launch (or after a material policy version bump)
/// only — stored version skips the page on later cold starts. Face ID runs
/// on this page; after it succeeds the same page is usable. Agree enters
/// Main. Never a cream lock. Never on passerby tapper.
enum ConsentSettings {
    static let acceptedVersionKey = "redmed.consentAcceptedVersion"
    static let currentVersion = "4.7"

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
    /// Returning owners skip the gate — first SwiftUI frame is Main.
    @State private var hasAccepted = ConsentSettings.hasAcceptedCurrent
    @State private var contentArmed = ConsentSettings.hasAcceptedCurrent
    /// First launch: Face ID on this page before Agree is usable.
    /// Returning owners never show this page, so start verified.
    @State private var faceVerified = ConsentSettings.hasAcceptedCurrent
    @State private var isAuthenticating = false
    @State private var didAutoPrompt = false
    @State private var showRetry = false
    @State private var biometryFailed = false
    @State private var notInteractive = false
    @State private var unavailableReason: BiometricAuth.UnavailableReason?
    @State private var authGeneration = 0
    @State private var checked = false
    @State private var openPolicy: HelpDocument.Policy?
    @Environment(\.scenePhase) private var scenePhase
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
            if !hasAccepted {
                gate
            }
        }
        .onAppear {
            SnapshotSafeCover.shared.reveal()
            tryPromptFaceID()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeKeyNotification)) { _ in
            tryPromptFaceID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedDidEraseLocalData)) { _ in
            returnToAcknowledgment()
        }
        .task(id: authGeneration) {
            guard !hasAccepted, !faceVerified, isAuthenticating else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !hasAccepted, !faceVerified, isAuthenticating else { return }
            #if targetEnvironment(simulator)
            // Auto-success should already have landed. If it did not, do
            // not sit on a dead Authenticate alert — enter the usable page.
            isAuthenticating = false
            showRetry = false
            faceVerified = true
            OwnerRedMedGate.unlock()
            #else
            // Live Face ID / passcode puts the scene `.inactive`. Do not
            // tear that down at 1.5s — only kill a hung evaluate with no UI.
            if BiometricAuth.isEvaluating, scenePhase != .active { return }
            BiometricAuth.cancelInFlight()
            isAuthenticating = false
            showRetry = true
            #endif
        }
    }

    private func returnToAcknowledgment() {
        checked = false
        openPolicy = nil
        faceVerified = false
        isAuthenticating = false
        didAutoPrompt = false
        showRetry = false
        biometryFailed = false
        notInteractive = false
        unavailableReason = nil
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            hasAccepted = false
            contentArmed = false
        }
        tryPromptFaceID()
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

                    if !faceVerified {
                        Image(systemName: "faceid")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.redmedAccent)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Face ID")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("RedMed is a personal medical ID and first-aid reference on this iPhone. It is not a medical device, does not diagnose or treat, and does not replace emergency dispatch. Always call emergency services first in a real emergency.")
                        Text("Your profile stays on this iPhone, and on a band if you write one — RedMed runs no server for it.")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .padding(14)
                    .redmedBox(flatten: false)

                    VStack(spacing: 0) {
                        Toggle("Haptic Feedback", isOn: $hapticsEnabled)
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
                                if on { LocationAccessSuggester.shared.refresh() }
                            }
                    }
                    .redmedBox(flatten: false)

                    VStack(spacing: 0) {
                        ForEach(Array(HelpDocument.Policy.allCases.enumerated()), id: \.element.id) { index, policy in
                            if index > 0 {
                                Divider().overlay(Color.redmedDivider).padding(.leading, RedMedChrome.pagePadX)
                            }
                            policyRow(policy)
                        }
                    }
                    .redmedBox(flatten: false)
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.bottom, 12)
            }

            VStack(spacing: 12) {
                if let unavailableReason {
                    Text(unavailableReason.message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(title: "Open Settings", flatten: false) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                } else if showRetry, !faceVerified {
                    if biometryFailed {
                        Text("Couldn't verify it's you. Try again.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                            .multilineTextAlignment(.center)
                    } else if notInteractive {
                        Text("Couldn't open Face ID. Try again.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                            .multilineTextAlignment(.center)
                    }
                    PrimaryButton(title: "Proceed", flatten: false) {
                        didAutoPrompt = false
                        showRetry = false
                        runFaceID()
                    }
                }

                if faceVerified {
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

                    PrimaryButton(title: "Agree And Continue", flatten: false) {
                        enterApp()
                    }
                }
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(Color.redmedBg)
        }
        .background { RedMedPageBackground() }
        .allowsHitTesting(faceVerified || showRetry || unavailableReason != nil)
        .sheet(item: $openPolicy) { policy in
            ConsentPolicySheet(policy: policy)
                .presentationBackground(Color.redmedBg)
        }
    }

    private func enterApp() {
        checked = true
        ConsentSettings.recordAcceptance()
        OwnerRedMedGate.unlock()
        RedMedHaptics.success()
        SnapshotSafeCover.shared.reveal()
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            contentArmed = true
            hasAccepted = true
        }
        // Honor the Location toggle. Do not fire iOS When-In-Use here —
        // they just agreed. Find Help / hospitals request when GPS starts.
        // Do not spawn a spare WKWebView on this turn — that raced the
        // owner RedMed embed and made tabs feel laggy after Agree.
        // NFCView warms the preview shell after that tab is first opened.
    }

    private func tryPromptFaceID() {
        guard !hasAccepted, !faceVerified, !didAutoPrompt, !isAuthenticating else { return }
        guard scenePhase != .background else { return }
        #if !targetEnvironment(simulator)
        guard BiometricAuth.hasKeyWindow else { return }
        #endif
        didAutoPrompt = true
        runFaceID()
    }

    private func runFaceID() {
        guard !hasAccepted, !faceVerified, !isAuthenticating else { return }
        isAuthenticating = true
        biometryFailed = false
        notInteractive = false
        unavailableReason = nil
        showRetry = false
        authGeneration &+= 1
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to continue.",
            force: true,
            allowPasscode: true
        ) { outcome in
            Task { @MainActor in
                isAuthenticating = false
                switch outcome {
                case .success:
                    faceVerified = true
                    showRetry = false
                    OwnerRedMedGate.unlock()
                case .notVerified:
                    biometryFailed = true
                    showRetry = true
                    VaultHistoryStore.shared.record(.unlockFailed, detail: "consent")
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

    @ViewBuilder
    private func policyRow(_ policy: HelpDocument.Policy) -> some View {
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

private struct ConsentPolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    let policy: HelpDocument.Policy

    var body: some View {
        NavigationStack {
            HelpPolicyPage(policy: policy, showsDoneChrome: true, onDone: { dismiss() })
        }
    }
}
