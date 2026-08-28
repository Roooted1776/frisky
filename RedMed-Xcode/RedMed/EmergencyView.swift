import SwiftUI
import CoreLocation

struct EmergencyView: View {
    /// Opacity keep-alive tabs never call `onDisappear` — ContentView passes
    /// whether 911 is the front tab so GPS + the seizure timer can tear down.
    var isVisible: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            PageHelpChrome()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    PrimaryButton(
                        title: "Call \(EmergencyNumber.current)",
                        systemImage: "phone.fill"
                    ) {
                        PublicEmergencyAid.dial()
                    }

                    FindHelpLocationBlock(isVisible: isVisible)
                    FindHelpSOSButton()
                    SeizureTimerStrip(isVisible: isVisible)

                    InfoCard(
                        icon: "cross.fill",
                        title: "Roadside First Response",
                        numbered: true,
                        items: [
                            "Turn on hazards. Don't move injured — unless fire or traffic danger.",
                            "Check breathing. Tilt head, lift chin. If no pulse — start CPR.",
                            "Press hard on bleeding. Don't lift to check. Add cloth on top.",
                            "Keep them warm and still. Talk to them. Note time of injury."
                        ]
                    )

                    InfoCard(
                        icon: "info.circle.fill",
                        title: "What to Tell \(EmergencyNumber.current)",
                        numbered: false,
                        items: [
                            "Your exact location — read the GPS coordinates above.",
                            "Number of people injured and visible injuries.",
                            "If anyone is unconscious or not breathing.",
                            "Stay on the line — let the dispatcher guide you."
                        ]
                    )
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.visible)
        }
        .background { RedMedPageBackground() }
    }
}

/// GPS + copy — owns `LocationManager` so coordinate publishes stay local.
private struct FindHelpLocationBlock: View {
    var isVisible: Bool = true

    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GPSCard(location: locationEnabled ? locationManager.location : nil)
                .opacity(locationEnabled ? 1 : 0.45)

            CompactFillButton(
                title: locationEnabled ? "Copy coordinates" : "Location off — enable it the next time you unlock",
                disabled: !locationEnabled || locationManager.location == nil
            ) {
                if locationEnabled, let loc = locationManager.location {
                    SecurePasteboard.copyEphemeral(
                        "\(loc.coordinate.latitude), \(loc.coordinate.longitude)"
                    )
                    RedMedHaptics.light()
                }
            }
        }
        .task(id: isVisible) {
            guard isVisible else {
                locationManager.stop()
                return
            }
            await Task.yield()
            if locationEnabled {
                locationManager.start()
            }
        }
        .onChange(of: locationEnabled) { _, on in
            guard isVisible else { return }
            if on {
                locationManager.start()
            } else {
                locationManager.stop()
            }
        }
        .onDisappear {
            locationManager.stop()
        }
    }
}

/// SOS control observes crash guard alone — keeps the rest of Find Help from rebuilding on arm ticks.
private struct FindHelpSOSButton: View {
    @ObservedObject private var survivalAlarm = CrashMotionGuard.shared

    var body: some View {
        CompactFillButton(
            title: survivalAlarm.isArmed ? "Stop the alarm" : "SOS · Locate me",
            systemImage: survivalAlarm.isArmed ? "speaker.slash.fill" : "sos.circle.fill",
            fill: survivalAlarm.isArmed ? .redmedAccent : .redmedDark
        ) {
            var t = Transaction()
            t.animation = nil
            withTransaction(t) {
                if survivalAlarm.isArmed {
                    RedMedHaptics.medium()
                    survivalAlarm.disarm()
                } else {
                    RedMedHaptics.heavy()
                    survivalAlarm.armSOS()
                }
            }
        }
        .accessibilityLabel(survivalAlarm.isArmed ? "Stop the alarm" : "SOS Locate me")
    }
}

/// Compact seizure stopwatch on Find Help — no aid copy.
/// At 5:00 the strip shows an explicit Call button. It never auto-dials.
struct SeizureTimerStrip: View {
    var isVisible: Bool = true

    @State private var running = false
    @State private var elapsed: TimeInterval = 0
    @State private var engine = SeizureTimerEngine()

    private static let callAt: TimeInterval = 5 * 60

    private var pastThreshold: Bool { elapsed >= Self.callAt }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SEIZURE")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(0.8)
                    .foregroundColor(.redmedMuted)
                Text(format(elapsed))
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(pastThreshold ? .redmedAccent : .redmedDark)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 56, alignment: .leading)

            Text(pastThreshold ? "5:00 — tap Call" : "Call \(EmergencyNumber.current) at 5:00")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(pastThreshold ? .redmedAccent : .redmedMuted)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                if pastThreshold {
                    Button("Call") {
                        RedMedHaptics.medium()
                        PublicEmergencyAid.dial()
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.redmedAccent)
                    .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                    .buttonStyle(RedMedPressStyle(scale: 0.95, haptic: nil))
                    .accessibilityLabel("Call \(EmergencyNumber.current)")
                    .accessibilityHint("Opens the Phone app. RedMed never dials by itself.")
                }

                Button("Reset") {
                    RedMedHaptics.light()
                    stop(reset: true)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.redmedDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.redmedBg)
                .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                        .strokeBorder(Color.redmedDivider, lineWidth: 1)
                )
                .buttonStyle(RedMedPressStyle(scale: 0.95, haptic: nil))
                .disabled(!running && elapsed == 0)
                .opacity((!running && elapsed == 0) ? 0.45 : 1)

                Button(running ? "Stop" : "Start") {
                    if running {
                        RedMedHaptics.light()
                        stop(reset: false)
                    } else {
                        RedMedHaptics.medium()
                        start()
                    }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(running ? .redmedDark : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(running ? Color.redmedBg : Color.redmedAccent)
                .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                        .strokeBorder(Color.redmedDivider, lineWidth: running ? 1 : 0)
                )
                .animation(RedMedMotion.snappy, value: running)
                .buttonStyle(RedMedPressStyle(scale: 0.95, haptic: nil))
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .redmedBox()
        .onChange(of: isVisible) { _, visible in
            if !visible { stop(reset: false) }
        }
        .onDisappear { stop(reset: false) }
    }

    private func start() {
        guard isVisible else { return }
        stop(reset: true)
        running = true
        let started = Date()
        engine.task = Task { @MainActor in
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(started)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stop(reset: Bool) {
        engine.task?.cancel()
        engine.task = nil
        running = false
        if reset { elapsed = 0 }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private final class SeizureTimerEngine {
    var task: Task<Void, Never>?
}
