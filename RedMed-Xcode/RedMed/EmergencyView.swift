import SwiftUI
import CoreLocation

struct EmergencyView: View {
    @Environment(\.isScannerSession) private var isScannerSession
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @StateObject private var locationManager = LocationManager()
    @State private var showSatellite = false

    var body: some View {
        VStack(spacing: 0) {
            // Location nudge lives in Help → Settings only — not on Find Help chrome.
            NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Text("Locator on — full brightness, beep every 5s. Crash impact arms siren + brightness. Stop the detection on Aid.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)

                    // NO CELL SIGNAL — top of Find Help (replaces call-first-contact)
                    NoCellSignalCard(showSatellite: $showSatellite)

                    // GPS CARD
                    GPSCard(location: locationEnabled ? locationManager.location : nil)
                        .padding(.vertical, 4)
                        .opacity(locationEnabled ? 1 : 0.45)

                    // COPY COORDINATES
                    Button {
                        if locationEnabled, let loc = locationManager.location {
                            UIPasteboard.general.string = "\(loc.coordinate.latitude), \(loc.coordinate.longitude)"
                        }
                    } label: {
                        Text(locationEnabled ? "Copy coordinates" : "Location off — enable in Settings")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.redmedDark)
                            .clipShape(Capsule())
                    }
                    .disabled(!locationEnabled || locationManager.location == nil)

                    SeizureTimerStrip()

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

                    Text("Coordinates show on this screen only. RedMed has no servers.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .background(Color.redmedBg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.redmedBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Find Help").font(.system(size: 17, weight: .semibold)).foregroundColor(.redmedAccent)
                }
                if isScannerSession {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ScannerCloseButton()
                    }
                }
            }
            .task {
                // First paint of Find Help before Core Location work.
                await Task.yield()
                if locationEnabled {
                    locationManager.start()
                }
            }
            .onChange(of: locationEnabled) { _, on in
                if on {
                    locationManager.start()
                } else {
                    locationManager.stop()
                }
            }
            .onDisappear {
                locationManager.stop()
            }
            } // NavigationView
        } // VStack
        .maxBrightnessForVisibility()
        .locatorBeaconEveryFiveSeconds()
    }
}

/// Compact seizure stopwatch on Find Help — no aid copy. Auto-dials the local
/// emergency number at 5:00.
struct SeizureTimerStrip: View {
    @State private var running = false
    @State private var elapsed: TimeInterval = 0
    @State private var task: Task<Void, Never>?

    private static let callAt: TimeInterval = 5 * 60

    private var pastThreshold: Bool { elapsed >= Self.callAt }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("SEIZURE")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(0.8)
                    .foregroundColor(.redmedMuted)
                Text(format(elapsed))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(pastThreshold ? .redmedAccent : .redmedDark)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 64, alignment: .leading)

            Text(pastThreshold ? "5:00 — call" : "→ \(EmergencyNumber.current) at 5:00")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(pastThreshold ? .redmedAccent : .redmedMuted)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button(running ? "Stop" : "Start") {
                if running { stop(reset: false) } else { start() }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(running ? .redmedDark : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(running ? Color.white.opacity(0.9) : Color.redmedAccent)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.redmedDivider, lineWidth: running ? 1 : 0))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.redmedDivider, lineWidth: 1))
        .onDisappear { stop(reset: false) }
    }

    private func start() {
        stop(reset: true)
        running = true
        let started = Date()
        task = Task { @MainActor in
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(started)
                if elapsed >= Self.callAt {
                    stop(reset: false)
                    if let url = EmergencyNumber.dialURL {
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
        task?.cancel()
        task = nil
        running = false
        if reset { elapsed = 0 }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - GPS Card
struct GPSCard: View {
    let location: CLLocation?

    var latStr: String { location.map { String(format: "%.6f", $0.coordinate.latitude) } ?? "–––" }
    var lonStr: String { location.map { String(format: "%.6f", $0.coordinate.longitude) } ?? "–––" }
    var accuracy: String { location.map { "±\(Int($0.horizontalAccuracy)) m" } ?? "––" }

    var body: some View {
        VStack(spacing: 6) {
            Text("LIVE GPS")
                .font(.system(size: 9, weight: .bold))
                .kerning(1.1)
                .foregroundColor(.redmedAccent)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(Color.redmedAccent.opacity(0.1)))

            Text("\(latStr), \(lonStr)")
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundColor(.redmedDark)
                .multilineTextAlignment(.center)

            Text("Accuracy \(accuracy)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let icon: String
    let title: String
    let numbered: Bool
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.redmedAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedDark)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(numbered ? "\(i+1)" : "→")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.redmedAccent)
                            .frame(width: 12)
                        Text(item)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.redmedDark)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
    }
}

// MARK: - No Cell Signal
struct NoCellSignalCard: View {
    @Binding var showSatellite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showSatellite.toggle() } } label: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.redmedAccent)
                    Text("No cell signal?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.redmedAccent)
                    Spacer()
                    Image(systemName: showSatellite ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.redmedMuted)
                }
            }
            .padding(14)

            if showSatellite {
                Text("iPhone 14+ (iOS 16.1+): hold Side + Volume until Emergency SOS appears, or Settings → Emergency SOS.")
                    .font(.system(size: 11))
                    .foregroundColor(.redmedMuted)
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// Created only in `start()` — never at view/`@main` init.
    private var manager: CLLocationManager?
    @Published var location: CLLocation?

    func start() {
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
            m.requestLocation()
            m.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func stop() {
        manager?.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        // Delegate runs on the thread that created the manager (main here).
        if Thread.isMainThread {
            location = latest
        } else {
            DispatchQueue.main.async { self.location = latest }
        }
        // Tighten once we have a fix so the card stays accurate while the tab is open.
        if manager.desiredAccuracy != kCLLocationAccuracyBest {
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = 5
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep listening — GPS can fail once then recover outdoors.
    }
}
