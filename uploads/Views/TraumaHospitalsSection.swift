import SwiftUI
import CoreLocation

/// Offline trauma hospital picker — shared by Find 911 and the NFC emergency card.
struct TraumaHospitalsSection: View {
    @Environment(\.layoutMetrics) private var layout

    /// When set (Find 911), Google Geocoding may auto-select state/county from GPS.
    var gpsCoordinate: CLLocationCoordinate2D?

    @AppStorage("redMedTraumaState") private var traumaState = ""
    @AppStorage("redMedTraumaCounty") private var traumaCounty = ""
    @State private var googleRegionNote: String?

    var body: some View {
        let needsCounty = TraumaHospitalFinder.needsCountyPicker(for: traumaState)
        let hospitals = TraumaHospitalFinder.resolvedHospitals(state: traumaState, county: traumaCounty)

        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: "Trauma hospitals", tint: AppTheme.medical)
            Text("For transport when they may not survive if you wait for a closer hospital.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.85))
            Text("Verified trauma centers only — pick your state. County appears only when the list is long (30+).")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)

            if let googleRegionNote {
                Text(googleRegionNote)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.medical)
            }

            Picker("State", selection: $traumaState) {
                Text("Select state").tag("")
                ForEach(TraumaHospitalFinder.states, id: \.self) { state in
                    Text(state).tag(state)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: traumaState) { _ in
                traumaCounty = ""
            }

            if needsCounty {
                Picker("County", selection: $traumaCounty) {
                    Text("Select county").tag("")
                    ForEach(TraumaHospitalFinder.counties(in: traumaState), id: \.self) { county in
                        Text(county).tag(county)
                    }
                }
                .pickerStyle(.menu)
            }

            if !traumaState.isEmpty && (!needsCounty || !traumaCounty.isEmpty) {
                if hospitals.isEmpty {
                    Text("None in this area")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(hospitals) { hospital in
                        HStack(alignment: .top, spacing: layout.spaceMD) {
                            VStack(alignment: .leading, spacing: layout.spaceXS) {
                                Text(hospital.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(hospital.levelLabel) · \(hospital.city), \(hospital.state)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.muted)
                                if !hospital.phone.isEmpty {
                                    Text(hospital.phone)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                            }
                            Spacer(minLength: layout.spaceSM)
                            if let url = hospital.mapsURL {
                                Link("Maps", destination: url)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, layout.spaceMD)
                                    .padding(.vertical, layout.spaceSM)
                                    .background(AppTheme.medical)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(layout.spaceMD)
                        .appCard(elevated: false)
                    }
                    Text("Call 911 first. Tell the dispatcher you need trauma-center transport and your location.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .task(id: gpsCoordinate.map { "\($0.latitude),\($0.longitude)" }) {
            guard let coordinate = gpsCoordinate else { return }
            guard let region = await GoogleGeocoder.reverseGeocode(coordinate: coordinate) else { return }
            traumaState = region.state
            traumaCounty = TraumaHospitalFinder.matchCounty(state: region.state, name: region.county) ?? ""
            googleRegionNote = "Region from GPS (Google) — offline trauma centers below."
        }
    }
}
