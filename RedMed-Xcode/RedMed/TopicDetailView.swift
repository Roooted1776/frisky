import SwiftUI
import MapKit

extension AidTopic: Identifiable {}

struct TopicDetailView: View {
    let topic: AidTopic
    @Environment(\.dismiss) var dismiss
    /// Engine lives in the view hierarchy — prepared on appear, fired on tap / beat.
    /// Enable/disable lives on the Before you continue screen (not on this card).
    @StateObject private var hapticEngine = HapticEngine()
    @State private var cprRunning = false
    @State private var cprCount = 0
    @State private var cprPhase = "compress" // or "breathe"
    @State private var cprPulse = false
    @State private var cprTimer: Timer? = nil

    var isCPR: Bool { topic.id == "cpr" }
    var isTraumaHospitals: Bool { topic.id == "trauma-hospitals" }

    func stopCPR() {
        cprTimer?.invalidate(); cprTimer = nil
        cprRunning = false; cprCount = 0; cprPhase = "compress"; cprPulse = false
    }

    func startCPR() {
        cprTimer?.invalidate()
        cprRunning = true; cprCount = 0; cprPhase = "compress"; cprPulse = false
        // Tap → calculated haptic execution, then metronome ticks.
        hapticEngine.playCompressionBeat()
        cprPulse = true
        scheduleTick(after: 0.545)
    }

    func scheduleTick(after interval: TimeInterval) {
        cprTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                tick()
            }
        }
    }

    func tick() {
        guard cprRunning else { return }
        cprPulse.toggle()
        if cprPhase == "compress" {
            let next = cprCount + 1
            if next >= 30 {
                cprCount = 30; cprPhase = "breathe"
                hapticEngine.playBreathCue()
                scheduleTick(after: 3.2)
            } else {
                cprCount = next
                hapticEngine.playCompressionBeat()
                scheduleTick(after: 0.545)
            }
        } else {
            cprCount = 0; cprPhase = "compress"
            hapticEngine.playCompressionBeat()
            scheduleTick(after: 0.545)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            BrandWordmarkHeader()

            // Pane-style chrome — Back leading, Help trailing.
            HStack(alignment: .center, spacing: 12) {
                ChromeTextAction(title: "Back", weight: .bold) { dismiss() }
                Spacer(minLength: 0)
                OwnerHelpButton()
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 2)
            .padding(.bottom, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(topic.title)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isCPR {
                        VStack(spacing: 16) {
                            Text("BEAT & BREATH COUNTER")
                                .font(.system(size: 12, weight: .bold))
                                .kerning(0.6)
                                .foregroundColor(.redmedMuted)
                                .fitsContainer(lines: 1, minScale: 0.7, alignment: .center)
                            ZStack {
                                Circle()
                                    .fill(cprPhase == "breathe" ? Color(red: 0.055, green: 0.647, blue: 0.914) : Color.redmedAccent)
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(cprPulse ? 1.14 : 1.0)
                                    .animation(.easeOut(duration: 0.16), value: cprPulse)
                                    .shadow(color: Color.redmedAccent.opacity(0.32), radius: 10, y: 4)
                                    // Pulses continuously at the CPR metronome rate — flatten
                                    // fill+shadow to one GPU texture so each beat just scales
                                    // a bitmap instead of recompositing a soft shadow on CPU.
                                    .drawingGroup()
                                Text("\(cprCount)")
                                    .font(.system(size: 32, weight: .heavy))
                                    .foregroundColor(.white)
                                    .fitsContainer(lines: 1, minScale: 0.6, alignment: .center)
                            }
                            Text(cprPhase == "breathe" ? "Give 2 breaths" : "Push hard, push fast")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.redmedAccent)
                                .fitsContainer(lines: 2, minScale: 0.7, alignment: .center)
                            Text("110 beats/min · haptic + click · 30 compressions, then 2 breaths")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .fitsContainer(lines: 2, minScale: 0.75, alignment: .center)
                                .multilineTextAlignment(.center)
                            if cprRunning {
                                PrimaryButton(title: "Stop") { stopCPR() }
                            } else {
                                PrimaryButton(title: "Start beat") { startCPR() }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .redmedBox()
                        .padding(.bottom, 22)
                    }

                    // RECOGNIZE
                    Text("Recognize")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .fitsContainer(lines: 1, minScale: 0.7, alignment: .leading)
                        .kerning(0.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                        .padding(.top, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(topic.symptoms.enumerated()), id: \.offset) { i, sym in
                            Text(sym)
                                .font(.system(size: 15))
                                .foregroundColor(.redmedDark)
                                .fitsContainer(lines: 6, minScale: 0.75, alignment: .leading)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 13)
                            if i < topic.symptoms.count - 1 {
                                Divider().overlay(Color.redmedDivider)
                            }
                        }
                    }
                    .redmedBox()
                    .padding(.bottom, 22)

                    // WHAT TO DO
                    Text("What to do")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .fitsContainer(lines: 1, minScale: 0.7, alignment: .leading)
                        .kerning(0.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        ForEach(Array(topic.care.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.redmedAccent)
                                    .padding(.top, 4)
                                Text(step)
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedDark)
                                    .fitsContainer(lines: 6, minScale: 0.75, alignment: .leading)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            if i < topic.care.count - 1 {
                                Divider().overlay(Color.redmedDivider)
                            }
                        }
                    }
                    .redmedBox()
                    .padding(.bottom, 24)

                    if isTraumaHospitals {
                        // Child owns CLLocationManager — other aid topics never create it.
                        LiveNearbyHospitalsSection()
                    }
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.visible)
        }
        .background { RedMedPageBackground() }
        .presentsOwnerHelp()
        .onAppear {
            if isCPR { hapticEngine.prepare() }
        }
        .onDisappear {
            stopCPR()
            if isCPR { hapticEngine.shutdown() }
        }
    }
}

/// Owns MapKit + CLLocationManager only when the trauma-hospitals topic is open
/// and Location is enabled.
private struct LiveNearbyHospitalsSection: View {
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @StateObject private var hospitalFinder = NearbyHospitalFinder()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nearest Hospitals — Live")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.redmedAccent)
                .fitsContainer(lines: 1, minScale: 0.7, alignment: .leading)
                .kerning(0.5)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
                .padding(.top, 24)

            if !locationEnabled {
                Text("Location is off. Enable it on Before you continue (first launch or a policy update) or in iOS Settings to find nearby hospitals. Search uses Apple Maps on this phone.")
                    .font(.system(size: 13))
                    .foregroundColor(.redmedMuted)
                    .fitsContainer(lines: 6, minScale: 0.75, alignment: .leading)
                    .padding(.vertical, 12)
            } else if hospitalFinder.isLoading {
                HStack {
                    ProgressView()
                    Text("Finding hospitals near you…")
                        .font(.system(size: 14))
                        .foregroundColor(.redmedMuted)
                        .fitsContainer(lines: 2, minScale: 0.75, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if let err = hospitalFinder.errorMessage {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.redmedMuted)
                    .fitsContainer(lines: 4, minScale: 0.75, alignment: .leading)
                    .padding(.vertical, 12)
                Button("Try again") { hospitalFinder.search() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
            } else if hospitalFinder.hospitals.isEmpty {
                PrimaryButton(title: "Find hospitals near me") { hospitalFinder.search() }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(hospitalFinder.hospitals.enumerated()), id: \.element.id) { i, hosp in
                        Button {
                            hosp.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.redmedAccent)
                                    .frame(width: 20, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hosp.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.redmedAccent)
                                        .fitsContainer(lines: 2, minScale: 0.75, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(hosp.address.isEmpty ? String(format: "%.1f mi away", hosp.distanceMiles) : "\(hosp.address) · \(String(format: "%.1f", hosp.distanceMiles)) mi")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.redmedMuted)
                                        .fitsContainer(lines: 3, minScale: 0.75, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.redmedAccent)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if i < hospitalFinder.hospitals.count - 1 {
                            Divider().overlay(Color.redmedDivider)
                        }
                    }
                }
                .redmedBox()
            }
        }
        .task {
            guard locationEnabled else { return }
            hospitalFinder.search()
        }
        .onChange(of: locationEnabled) { _, on in
            if on { hospitalFinder.search() }
        }
    }
}
