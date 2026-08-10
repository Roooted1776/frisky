import CoreLocation
import SwiftUI
import UIKit

/// Manual SOS, opt-in motion assist, and seizure timer — placed under Live GPS on Find 911.
struct Find911SOSSection: View {
    @Environment(\.layoutMetrics) private var layout

    @ObservedObject var sos: EmergencySOSController
    @ObservedObject var motion: MotionAssistMonitor
    let isOffline: Bool

    @State private var seizureRunning = false
    @State private var seizureElapsed: TimeInterval = 0
    @State private var seizureTask: Task<Void, Never>?
    @State private var motionEnabledForSeizureSession = false

    private static let seizureAutoSOSSeconds: TimeInterval = 5 * 60

    var body: some View {
        VStack(spacing: layout.spaceMD) {
            SectionEyebrow(text: "Emergency SOS", tint: AppTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                sos.startCountdown(isOffline: isOffline)
            } label: {
                Text(isOffline ? "Emergency SOS · Satellite path" : "Emergency SOS")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(prominent: true))
            .disabled(sos.isCountingDown)

            Text(isOffline
                 ? "No cell path detected. Countdown ends on Satellite SOS steps — RedMed cannot start Apple Satellite SOS."
                 : "Cancelable countdown → optional third-party alert API (if configured) → Phone dials 911 → Messages texts your contacts. No RedMed server.")
                .font(layout.captionFont(weight: .medium))
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: Binding(
                get: { motion.isEnabled },
                set: { motion.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: layout.spaceXS) {
                    Text("Motion assist")
                        .font(layout.subheadlineFont(weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("While this screen is open, a hard sustained jolt starts the same SOS countdown. Off by default. Assistive only — not a medical device.")
                        .font(layout.captionFont())
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(AppTheme.accent)

            Divider().overlay(AppTheme.line)

            seizureBlock
        }
        .padding(.vertical, layout.cardPadV)
        .padding(.horizontal, layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .onChange(of: motion.didTrigger) { triggered in
            guard triggered else { return }
            motion.consumeTrigger()
            guard !sos.isCountingDown, !sos.showsSatelliteCoach else { return }
            sos.startCountdown(isOffline: isOffline)
        }
        .onDisappear {
            stopSeizureTimer(reset: false)
        }
    }

    private var seizureBlock: some View {
        VStack(alignment: .leading, spacing: layout.spaceSM) {
            Text("Seizure timer")
                .font(layout.subheadlineFont(weight: .semibold))
                .foregroundStyle(AppTheme.ink)

            Text("Time it. Don’t restrain. Don’t put anything in the mouth. Call if first seizure, over 5 minutes, no recovery, injury, or in water.")
                .font(layout.captionFont())
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Text(formatElapsed(seizureElapsed))
                .font(.system(size: layout.s(28), weight: .bold, design: .monospaced))
                .foregroundStyle(seizureElapsed >= Self.seizureAutoSOSSeconds ? AppTheme.accent : AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, layout.spaceXS)

            HStack(spacing: layout.spaceSM) {
                Button(seizureRunning ? "Stop timer" : "Start seizure timer") {
                    if seizureRunning {
                        stopSeizureTimer(reset: false)
                    } else {
                        startSeizureTimer()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Call now") {
                    sos.fireNow(isOffline: sos.isOfflineCheck())
                }
                .buttonStyle(PrimaryButtonStyle(prominent: false))
            }

            if seizureRunning {
                Text("Motion assist is on for this timer session. At 5:00 the same SOS path fires.")
                    .font(layout.caption2Font(weight: .medium))
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func startSeizureTimer() {
        stopSeizureTimer(reset: true)
        seizureRunning = true
        if !motion.isEnabled {
            motion.setEnabled(true)
            motionEnabledForSeizureSession = true
        }
        let started = Date().addingTimeInterval(-seizureElapsed)
        seizureTask = Task { @MainActor in
            while !Task.isCancelled {
                seizureElapsed = Date().timeIntervalSince(started)
                if seizureElapsed >= Self.seizureAutoSOSSeconds {
                    stopSeizureTimer(reset: false)
                    sos.fireNow(isOffline: sos.isOfflineCheck())
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func stopSeizureTimer(reset: Bool) {
        seizureTask?.cancel()
        seizureTask = nil
        seizureRunning = false
        if reset { seizureElapsed = 0 }
        if motionEnabledForSeizureSession {
            motion.setEnabled(false)
            motionEnabledForSeizureSession = false
        }
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Full-screen cancelable countdown overlay.
struct EmergencySOSCountdownOverlay: View {
    @Environment(\.layoutMetrics) private var layout
    @ObservedObject var sos: EmergencySOSController
    var isOffline: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: layout.spaceLG) {
                Text(isOffline ? "Satellite SOS steps in" : "Calling 911 in")
                    .font(layout.subheadlineFont(weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(sos.secondsRemaining)")
                    .font(.system(size: layout.s(72), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("Tap Cancel if this was a false alarm.")
                    .font(layout.captionFont(weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                Button("Cancel") { sos.cancel() }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: layout.s(220))
            }
            .padding(layout.spaceXL)
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// Offline Satellite SOS coach — RedMed cannot invoke Apple’s Satellite SOS API.
struct SatelliteSOSCoachView: View {
    @Environment(\.layoutMetrics) private var layout

    let coordinate: CLLocationCoordinate2D?
    let accuracy: CLLocationAccuracy?
    let locationTimestamp: Date?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.spaceLG) {
                    SoftStatusChip(
                        text: "No usable cell path. RedMed cannot start Emergency SOS via satellite — use the iPhone hardware steps below.",
                        warning: true
                    )

                    VStack(alignment: .leading, spacing: layout.spaceSM) {
                        Text("1. Hold the Side button and either Volume button until the Emergency SOS slider appears.")
                        Text("2. Drag Emergency SOS, or keep holding for the countdown.")
                        Text("3. If there’s no cellular, iPhone 14+ can connect via satellite when you have a clear view of the sky.")
                        Text("4. Read your GPS below to the dispatcher if the call connects.")
                    }
                    .font(layout.subheadlineFont(weight: .medium))
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                    if let c = coordinate {
                        VStack(alignment: .leading, spacing: layout.spaceXS) {
                            SectionEyebrow(text: "Live GPS", tint: AppTheme.medical)
                            Text(String(format: "%.6f, %.6f", c.latitude, c.longitude))
                                .font(.system(size: layout.s(20), design: .monospaced).weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                            Text(LocationFormatting.dms(latitude: c.latitude, longitude: c.longitude))
                                .font(.system(size: layout.s(13), design: .monospaced).weight(.semibold))
                                .foregroundStyle(AppTheme.ink.opacity(0.85))
                            if let accuracy, accuracy > 0 {
                                Text(String(format: "Accuracy ±%.0f m", accuracy))
                                    .font(layout.captionFont(weight: .semibold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            if let locationTimestamp {
                                Text("As of \(locationTimestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(layout.caption2Font())
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Button("Copy coordinates") {
                                UIPasteboard.general.string = LocationFormatting.coordsCopyText(
                                    latitude: c.latitude,
                                    longitude: c.longitude
                                )
                            }
                            .buttonStyle(InkButtonStyle())
                        }
                        .padding(layout.spaceLG)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard()
                    } else {
                        Text("GPS not ready yet — tell the dispatcher landmarks and street names.")
                            .font(layout.captionFont(weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                    }

                    Link("Apple guide: Emergency SOS via satellite",
                         destination: URL(string: "https://support.apple.com/en-us/102669")!)
                        .font(layout.subheadlineFont(weight: .semibold))
                        .foregroundStyle(AppTheme.accent)

                    Call911Button(title: "Try Phone · dial 911 anyway", secondary: true)

                    Text("This coach is not Apple Crash Detection or Satellite SOS. RedMed has no servers and cannot place a satellite call.")
                        .font(layout.caption2Font(weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
                .padding(.horizontal, layout.screenPad)
                .padding(.vertical, layout.spaceLG)
                .padding(.bottom, layout.screenBottomLarge)
            }
            .scrollIndicators(.visible, axes: .vertical)
            .screenAtmosphere()
            .navigationTitle("Satellite SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }
}
