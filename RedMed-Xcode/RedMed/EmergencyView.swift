import SwiftUI
import CoreLocation

struct EmergencyView: View {
    /// Opacity keep-alive tabs never call `onDisappear` — ContentView passes
    /// whether 911 is the front tab so GPS + seizure autodial can tear down.
    var isVisible: Bool = true

    var body: some View {
        // Fixed cream chrome (no NavigationView / system toolbar fill).
        // No page header text / BrandWordmark — content-first like RedMed / Aid.
        // Help is a sibling row (same as RedMed) so Call / Find Help sit below it.
        VStack(spacing: 0) {
            PageHelpChrome()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    // Call first — EMS dial is the primary action on this tab.
                    PrimaryButton(
                        title: "Call \(EmergencyNumber.current)",
                        systemImage: "phone.fill"
                    ) {
                        PublicEmergencyAid.dial()
                    }

                    // GPS observes LocationManager alone — SOS / cards must not
                    // rebuild on every coordinate tick.
                    FindHelpLocationBlock(isVisible: isVisible)

                    // Isolated observer — SOS arm must not rebuild the whole 911 scroll.
                    FindHelpSOSButton()

                    SeizureTimerStrip(isVisible: isVisible)

                    // ROADSIDE FIRST RESPONSE
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
                title: locationEnabled ? "Copy coordinates" : "Location off — enable in Help → Settings",
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
            // First paint of Find Help before Core Location work.
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
        // Visibility start/stop is owned by `.task(id: isVisible)` above.
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

/// Compact seizure stopwatch on Find Help — no aid copy. Auto-dials the local
/// emergency number at 5:00.
struct SeizureTimerStrip: View {
    /// When Find Help is hidden under opacity keep-alive, cancel autodial.
    var isVisible: Bool = true

    @State private var running = false
    @State private var elapsed: TimeInterval = 0
    /// Reference so hide/stop clears arming the tick Task can still see.
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

            Text(pastThreshold ? "5:00 — call" : "→ \(EmergencyNumber.current) at 5:00")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(pastThreshold ? .redmedAccent : .redmedMuted)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
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
        engine.autodialArmed = true
        let started = Date()
        let engine = self.engine
        engine.task = Task { @MainActor in
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(started)
                if elapsed >= Self.callAt {
                    let shouldDial = engine.autodialArmed
                    stop(reset: false)
                    if shouldDial, let url = EmergencyNumber.dialURL {
                        // Call the completion-handler overload explicitly: bare
                        // `open(_:)` resolves to the async one in here and would
                        // need `await`.
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    return
                }
                // Display is mm:ss — 1s ticks are enough (was 200ms).
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stop(reset: Bool) {
        engine.task?.cancel()
        engine.task = nil
        engine.autodialArmed = false
        running = false
        if reset { elapsed = 0 }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Holds the seizure tick Task + autodial arm across opacity tab hides.
private final class SeizureTimerEngine {
    var task: Task<Void, Never>?
    var autodialArmed = false
}

// MARK: - GPS Card
struct GPSCard: View {
    let location: CLLocation?

    var latStr: String { location.map { String(format: "%.6f", $0.coordinate.latitude) } ?? "–––" }
    var lonStr: String { location.map { String(format: "%.6f", $0.coordinate.longitude) } ?? "–––" }
    var accuracy: String { location.map { "±\(Int($0.horizontalAccuracy)) m" } ?? "––" }

    var body: some View {
        VStack(spacing: 4) {
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

            Text("Accuracy \(accuracy)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.redmedMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .redmedBox()
    }
}

// MARK: - Info Card
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

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// Created only in `start()` — never at view/`@main` init.
    private var manager: CLLocationManager?
    @Published var location: CLLocation?
    /// Set while a request is outstanding (including a pending authorization
    /// prompt); cleared by `stop()`. Guards `locationManagerDidChangeAuthorization`
    /// so a permission callback that lands after the owner has left the 911 tab
    /// (`stop()` already called) can't still fire a one-shot GPS read — matches
    /// `NearbyHospitalFinder`'s `isLoading` guard on the same delegate callback.
    private var wantsLocation = false

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
            // Prompt only — wait for authorization callback before GPS.
            m.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            // One-shot fix is enough for EMS coordinate copy — continuous GPS
            // stays for accuracy callbacks only if the first fix is stale/nil.
            m.requestLocation()
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
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        // Skip near-identical fixes — every @Published tick used to rebuild Find Help.
        if let prev = location,
           prev.distance(from: latest) < 8,
           abs(prev.horizontalAccuracy - latest.horizontalAccuracy) < 15 {
            return
        }
        // Delegate runs on the thread that created the manager (main here).
        if Thread.isMainThread {
            location = latest
        } else {
            DispatchQueue.main.async { self.location = latest }
        }
        // Keep the relaxed start settings — Best+5m used to rebuild Find Help constantly.
        // HundredMeters + 25m (set in start) is enough for EMS coordinate copy.
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep listening — GPS can fail once then recover outdoors.
    }
}
