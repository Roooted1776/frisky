import SwiftUI

/// Legal consent. Every cold start of the owner app (fresh process), then
/// Main after Agree this process. Stored version is the legal record only —
/// it does not skip the page. Never a cream lock. Never on passerby tapper.
enum ConsentSettings {
    static let acceptedVersionKey = "redmed.consentAcceptedVersion"
    static let currentVersion = "4.6"

    /// Legal record only — does not hide the gate on cold start.
    static var hasAcceptedCurrent: Bool {
        UserDefaults.standard.string(forKey: acceptedVersionKey) == currentVersion
    }

    static func recordAcceptance() {
        UserDefaults.standard.set(currentVersion, forKey: acceptedVersionKey)
    }

    /// After Erase all data — next open shows Before you continue.
    static func clearAcceptance() {
        UserDefaults.standard.removeObject(forKey: acceptedVersionKey)
        acceptedThisProcess = false
    }

    /// Set on Agree this process. Dies with the process so the next cold
    /// start shows Before you continue even if the stored version matches.
    static var acceptedThisProcess = false
}

struct ConsentGateView<Content: View>: View {
    @State private var hasAccepted = ConsentSettings.acceptedThisProcess
    @State private var contentArmed = ConsentSettings.acceptedThisProcess
    @State private var checked = false
    @State private var openPolicy: HelpDocument.Policy?
    @AppStorage(RedMedHaptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @ObservedObject private var locationSuggester = LocationAccessSuggester.shared
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
            // Cold start: keep Main unmounted until Agree so the gate is the
            // first real page, not a cream hang over a loading WKWebView.
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedDidEraseLocalData)) { _ in
            returnToAcknowledgment()
        }
    }

    private func returnToAcknowledgment() {
        checked = false
        openPolicy = nil
        ConsentSettings.acceptedThisProcess = false
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            hasAccepted = false
            contentArmed = false
        }
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
                                if on { locationSuggester.refresh() }
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

                PrimaryButton(title: "Agree And Continue", disabled: !checked, flatten: false) {
                    enterApp()
                }
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(Color.redmedBg)
        }
        .background { RedMedPageBackground() }
        .sheet(item: $openPolicy) { policy in
            ConsentPolicySheet(policy: policy)
                .presentationBackground(Color.redmedBg)
        }
    }

    private func enterApp() {
        checked = true
        ConsentSettings.recordAcceptance()
        ConsentSettings.acceptedThisProcess = true
        RedMedHaptics.success()
        SnapshotSafeCover.shared.reveal()
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            contentArmed = true
            hasAccepted = true
        }
        // Honor the Location toggle. Request When-In-Use only if it stayed on.
        LocationAccessSuggester.shared.requestWhenInUseIfNeeded()
        // Do not spawn a spare WKWebView on this turn — that raced the
        // owner RedMed embed and made tabs feel laggy after Agree.
        // NFCView warms the preview shell after that tab is first opened.
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
