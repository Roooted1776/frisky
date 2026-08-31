import SwiftUI
import CoreLocation

struct EmergencyView: View {
    var isVisible: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            PageHelpChrome()
            ScrollView {
                // Short, fixed page (~6 children). LazyVStack would estimate
                // off-screen height and keep bookkeeping with no benefit.
                VStack(alignment: .leading, spacing: 10) {
                    FindHelpLocationBlock(isVisible: isVisible)
                    FindHelpSOSButton()
                    CrashDialCountdownStrip()
                    PrimaryButton(
                        title: "Call \(EmergencyNumber.current)",
                        systemImage: "phone.fill"
                    ) {
                        PublicEmergencyAid.dial()
                    }
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
                        title: "What To Tell \(EmergencyNumber.current)",
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
    }
}

private struct FindHelpLocationBlock: View {
    var isVisible: Bool = true
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        VStack(spacing: 0) {
            CompactFillButton(title: "Refresh", disabled: !locationEnabled) {
                guard locationEnabled else { return }
                RedMedHaptics.light()
                locationManager.refresh()
            }
            CompactFillButton(
                title: locationEnabled ? "Copy Coordinates" : "Location Off — Enable It On Before You Continue Or In Settings",
                disabled: !locationEnabled || locationManager.location == nil
            ) {
                if locationEnabled, let loc = locationManager.location {
                    SecurePasteboard.copyEphemeral(
                        "\(loc.coordinate.latitude), \(loc.coordinate.longitude)"
                    )
                    RedMedHaptics.light()
                }
            }
            .padding(.top, 7)
            GPSCard(
                location: locationEnabled ? locationManager.location : nil
            )
            .padding(.top, 10)
        }
        .task(id: isVisible) {
            guard isVisible else {
                locationManager.stop()
                return
            }
            await Task.yield()
            // Let 911 paint first — startUpdatingLocation hitch on the tap turn.
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled, isVisible else { return }
            if locationEnabled { locationManager.start() }
        }
        .onChange(of: locationEnabled) { _, on in
            guard isVisible else { return }
            if on { locationManager.start() } else { locationManager.stop() }
        }
        .onDisappear { locationManager.stop() }
    }
}

private struct FindHelpSOSButton: View {
    @ObservedObject private var survivalAlarm = CrashMotionGuard.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CompactFillButton(
                title: survivalAlarm.isArmed ? "Stop The Alarm" : "SOS · Locate Me",
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
            .accessibilityLabel(survivalAlarm.isArmed ? "Stop The Alarm" : "SOS Locate Me")
            .accessibilityHint(
                survivalAlarm.isArmed
                    ? "Stops the alarm and cancels a pending crash call."
                    : "Calls \(EmergencyNumber.current) immediately and starts the locator alarm."
            )
            Text(AppConfig.CrashAlarmCopy.findHelpNote)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// US Crash Detection delay (10s + 30s). Hidden after SOS (already dialed) and after the call fires.
private struct CrashDialCountdownStrip: View {
    @ObservedObject private var survivalAlarm = CrashMotionGuard.shared

    var body: some View {
        if let remaining = survivalAlarm.crashDialRemaining {
            Text("Calling \(EmergencyNumber.current) in \(format(remaining))")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.redmedAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .redmedBox()
                .accessibilityLabel(
                    "Calling \(EmergencyNumber.current) in \(format(remaining)). Tap Stop The Alarm to cancel."
                )
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = max(0, Int(ceil(t)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

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
            Text(pastThreshold ? "5:00 — Tap Call" : "Call \(EmergencyNumber.current) At 5:00")
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

struct GPSCard: View {
    let location: CLLocation?
    var latStr: String { location.map { String(format: "%.6f", $0.coordinate.latitude) } ?? "–––" }
    var lonStr: String { location.map { String(format: "%.6f", $0.coordinate.longitude) } ?? "–––" }
    var accuracy: String { location.map { "±\(Int($0.horizontalAccuracy)) m" } ?? "––" }
    var body: some View {
        VStack(spacing: 0) {
            Text("LIVE GPS")
                .font(.system(size: 9, weight: .bold))
                .kerning(1.1)
                .foregroundColor(.redmedAccent)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                        .fill(Color.redmedAccent.opacity(0.1))
                )
            Text("\(latStr), \(lonStr)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.redmedDark)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Text("Accuracy \(accuracy)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .redmedBox()
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let numbered: Bool
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 24, height: 24)
                    .background(Color.redmedAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.redmedDark)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text(numbered ? "\(i+1)" : "→")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.redmedAccent)
                            .frame(width: 14)
                        Text(item)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.redmedDark)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .redmedBox()
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    @Published var location: CLLocation?
    private var wantsLocation = false
    private var forceNextUpdate = false

    func refresh() {
        if !wantsLocation { start() }
        guard let m = manager else { return }
        switch m.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            forceNextUpdate = true
            // One-shot is ignored while startUpdatingLocation is running.
            m.stopUpdatingLocation()
            m.requestLocation()
        case .denied, .restricted:
            break
        case .notDetermined:
            m.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }

    func start() {
        wantsLocation = true
        let m: CLLocationManager
        if let existing = manager {
            m = existing
        } else {
            let created = CLLocationManager()
            created.delegate = self
            created.desiredAccuracy = kCLLocationAccuracyHundredMeters
            created.distanceFilter = 25
            manager = created
            m = created
        }
        switch m.authorizationStatus {
        case .notDetermined:
            m.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            m.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func stop() {
        wantsLocation = false
        manager?.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard wantsLocation else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let forced = forceNextUpdate
        forceNextUpdate = false
        if !forced,
           let prev = location,
           prev.distance(from: latest) < 8,
           abs(prev.horizontalAccuracy - latest.horizontalAccuracy) < 15 {
            return
        }
        if Thread.isMainThread {
            location = latest
        } else {
            DispatchQueue.main.async { self.location = latest }
        }
        if forced, wantsLocation {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        forceNextUpdate = false
        if wantsLocation {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            default:
                break
            }
        }
    }
}
