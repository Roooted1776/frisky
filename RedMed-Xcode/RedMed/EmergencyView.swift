import SwiftUI
import CoreLocation

struct EmergencyView: View {
    @EnvironmentObject var profile: ProfileData
    @StateObject private var locationManager = LocationManager()
    @State private var showSatellite = false
    /// Mount SOS after first GPS paint so opening 911 stays snappy.
    @State private var mountSOS = false

    func callFirstContact() {
        guard let c = profile.contacts.first else { return }
        let digits = c.detail.filter(\.isNumber)
        if let url = URL(string: "tel://\(digits)") { UIApplication.shared.open(url) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Text("Find 911")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.redmedDark)
                        .padding(.bottom, 2)

                    SecondaryButton("Call first emergency contact") { callFirstContact() }
                    Text("Calls your first saved contact — iPhone confirms before dialing.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)

                    // GPS CARD
                    GPSCard(location: locationManager.location)
                        .padding(.vertical, 4)

                    // Emergency SOS — under Live GPS; deferred one frame for fast first paint
                    if mountSOS {
                        Find911SOSBlock(locationManager: locationManager)
                    }

                    // COPY COORDINATES
                    Button {
                        if let loc = locationManager.location {
                            UIPasteboard.general.string = "\(loc.coordinate.latitude), \(loc.coordinate.longitude)"
                        }
                    } label: {
                        Text("Copy coordinates")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.redmedDark)
                            .clipShape(Capsule())
                    }

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
                        title: "What to Tell 911",
                        numbered: false,
                        items: [
                            "Your exact location — read the GPS coordinates above.",
                            "Number of people injured and visible injuries.",
                            "If anyone is unconscious or not breathing.",
                            "Stay on the line — let the dispatcher guide you."
                        ]
                    )

                    // COMMON TRAUMA GRID
                    CommonTraumaGrid()

                    // NO CELL SIGNAL
                    NoCellSignalCard(showSatellite: $showSatellite)

                    Text("Coordinates show on this screen only. RedMed has no servers.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .background(Color.redmedBg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Find 911").font(.system(size: 17, weight: .semibold)).foregroundColor(.redmedDark)
                }
            }
            // GPS after first layout; SOS one yield later so the GPS card paints first.
            .task {
                locationManager.start()
                await Task.yield()
                mountSOS = true
            }
            .onDisappear {
                locationManager.stop()
                mountSOS = false
            }
        }
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

// MARK: - Common Trauma Grid
struct CommonTraumaGrid: View {
    let cells: [(String, String)] = [
        ("Bleeding", "Press hard. Belt tourniquet on limb 2–3 in above. Note time."),
        ("Not Breathing", "Tilt head, lift chin. No pulse? 100–120/min hard compressions."),
        ("Spinal", "Don't move. Keep head still. Move only if fire or traffic."),
        ("Burns", "Running water 10+ min. No ice. Cover loosely."),
        ("Shock", "Lay flat, elevate legs. Keep warm. No food or water."),
        ("Seizure", "Time it. Don't restrain. Nothing in the mouth."),
        ("Hypothermia", "Remove wet clothes. Warm core slowly. No rubbing."),
        ("Heat", "Call 911 for stroke. Cool neck/armpits/groin fast."),
    ]

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.redmedAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Common Trauma Situations")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedDark)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(cells, id: \.0) { cell in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cell.0)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.redmedAccent)
                        Text(cell.1)
                            .font(.system(size: 9))
                            .foregroundColor(.redmedDark)
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.redmedBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                VStack(spacing: 8) {
                    Text("iPhone 14+ (iOS 16.1+): hold Side + Volume until Emergency SOS appears, or Settings → Emergency SOS.")
                        .font(.system(size: 11))
                        .foregroundColor(.redmedMuted)
                        .lineSpacing(3)
                    SecondaryButton("Open Phone · dial 911") {
                        if let url = URL(string: "tel://911") { UIApplication.shared.open(url) }
                    }
                }
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
    private let manager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        // Coarser first fix — Best accuracy waits longer before publishing.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 25
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        // One-shot first (fast), then continuous for the live GPS card.
        manager.requestLocation()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
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
