import SwiftUI
import CoreLocation
import MapKit

struct EmergencyView: View {
    @EnvironmentObject var profile: ProfileData
    @EnvironmentObject var emergencyLocation: EmergencyLocationService
    @StateObject private var hospitalFinder = NearbyHospitalFinder()
    @State private var showSatellite = false
    @State private var showPublicCard = false

    func callFirstContact() {
        guard let c = profile.contacts.first else {
            if let url = URL(string: "tel://911") { UIApplication.shared.open(url) }
            return
        }
        let digits = c.detail.filter(\.isNumber)
        if let url = URL(string: "tel://\(digits)") { UIApplication.shared.open(url) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Find 911")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.redmedDark)
                    Text("Call first. Share GPS second.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .padding(.bottom, 2)

                    PrimaryButton(title: "Call 911") {
                        if let url = URL(string: "tel://911") { UIApplication.shared.open(url) }
                    }

                    SecondaryButton("Scan emergency bracelet") { showPublicCard = true }
                    Text("Tap the band — their browser opens the emergency card.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    SecondaryButton("Call emergency contacts") { callFirstContact() }
                    Text("Pick a saved contact — iPhone asks before placing the call.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)

                    // GPS CARD
                    GPSCard(location: emergencyLocation.location)
                        .padding(.vertical, 4)

                    // COPY COORDINATES
                    Button {
                        if let loc = emergencyLocation.location {
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

                    // NEARBY TRAUMA HOSPITALS
                    NearbyHospitalsCard(finder: hospitalFinder, location: emergencyLocation.location)

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
            .onAppear { hospitalFinder.search(near: emergencyLocation.location) }
            .onChange(of: emergencyLocation.location) { _, loc in
                if loc != nil, hospitalFinder.hospitals.isEmpty, !hospitalFinder.isLoading {
                    hospitalFinder.search(near: loc)
                }
            }
            .sheet(isPresented: $showPublicCard) { PublicCardView(profile: profile) }
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
        ("Hypothermia", "Remove wet clothes. Warm slowly. No rubbing."),
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

// MARK: - Nearby Trauma Hospitals
struct NearbyHospitalsCard: View {
    @ObservedObject var finder: NearbyHospitalFinder
    let location: CLLocation?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.redmedAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Nearby Trauma Hospitals")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedDark)
            }

            if finder.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Finding hospitals near you…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if let err = finder.errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.redmedMuted)
                SecondaryButton("Try again") { finder.search(near: location) }
            } else if finder.hospitals.isEmpty {
                PrimaryButton(title: "Find hospitals near me") { finder.search(near: location) }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(finder.hospitals.enumerated()), id: \.offset) { i, hosp in
                        Button {
                            hosp.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.redmedAccent)
                                    .frame(width: 16, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hosp.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.redmedDark)
                                    Text(hosp.address.isEmpty ? String(format: "%.1f mi away", hosp.distanceMiles) : "\(hosp.address) · \(String(format: "%.1f", hosp.distanceMiles)) mi")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.redmedMuted)
                                }
                                Spacer()
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedAccent)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if i < finder.hospitals.count - 1 { Divider() }
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

