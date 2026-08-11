import SwiftUI
import MapKit

extension AidTopic: Identifiable {}

struct TopicDetailView: View {
    let topic: AidTopic
    @Environment(\.dismiss) var dismiss
    /// Engine lives in the view hierarchy — prepared on appear, fired on tap / beat.
    /// Enable/disable lives in Help → Settings only (not on this card).
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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isCPR {
                        VStack(spacing: 16) {
                            Text("BEAT & BREATH COUNTER")
                                .font(.system(size: 12, weight: .bold))
                                .kerning(0.6)
                                .foregroundColor(.redmedMuted)
                            ZStack {
                                Circle()
                                    .fill(cprPhase == "breathe" ? Color(red: 0.055, green: 0.647, blue: 0.914) : Color.redmedAccent)
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(cprPulse ? 1.14 : 1.0)
                                    .animation(.easeOut(duration: 0.16), value: cprPulse)
                                    .shadow(color: Color.redmedAccent.opacity(0.32), radius: 10, y: 4)
                                Text("\(cprCount)")
                                    .font(.system(size: 32, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                            Text(cprPhase == "breathe" ? "Give 2 breaths" : "Push hard, push fast")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.redmedDark)
                            Text("110 beats/min · 30 compressions, then 2 breaths")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.redmedMuted)
                                .multilineTextAlignment(.center)
                            if cprRunning {
                                Button("Stop") { stopCPR() }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.redmedDark)
                                    .clipShape(Capsule())
                            } else {
                                PrimaryButton(title: "Start beat") { startCPR() }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.bottom, 22)
                    }

                    // RECOGNIZE
                    Text("Recognize")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
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
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 13)
                            if i < topic.symptoms.count - 1 {
                                Divider().overlay(Color.black.opacity(0.06))
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 22)

                    // WHAT TO DO
                    Text("What to do")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
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
                                    .lineSpacing(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            if i < topic.care.count - 1 {
                                Divider().overlay(Color.black.opacity(0.06))
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 24)

                    if isTraumaHospitals {
                        // Child owns CLLocationManager — other aid topics never create it.
                        LiveNearbyHospitalsSection()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.redmedBg)
            .onAppear {
                if isCPR { hapticEngine.prepare() }
            }
            .onDisappear { stopCPR() }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.redmedBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Aid")
                                .font(.system(size: 17, weight: .regular))
                        }
                        .foregroundColor(.redmedAccent)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(topic.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                }
            }
        }
    }
}

/// Owns MapKit + CLLocationManager only when the trauma-hospitals topic is open
/// and Location is enabled in Help → Settings.
private struct LiveNearbyHospitalsSection: View {
    @AppStorage(AppSettings.locationEnabledKey) private var locationEnabled = true
    @StateObject private var hospitalFinder = NearbyHospitalFinder()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nearest Hospitals — Live")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.redmedAccent)
                .kerning(0.5)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
                .padding(.top, 24)

            if !locationEnabled {
                Text("Location is off. Enable it in Help → Settings to find nearby hospitals.")
                    .font(.system(size: 13))
                    .foregroundColor(.redmedMuted)
                    .padding(.vertical, 12)
            } else if hospitalFinder.isLoading {
                HStack {
                    ProgressView()
                    Text("Finding hospitals near you…")
                        .font(.system(size: 14))
                        .foregroundColor(.redmedMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if let err = hospitalFinder.errorMessage {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.redmedMuted)
                    .padding(.vertical, 12)
                Button("Try again") { hospitalFinder.search() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
            } else if hospitalFinder.hospitals.isEmpty {
                Button("Find hospitals near me") { hospitalFinder.search() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.redmedDark)
                    .clipShape(Capsule())
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
                                        .foregroundColor(.redmedDark)
                                    Text(hosp.address.isEmpty ? String(format: "%.1f mi away", hosp.distanceMiles) : "\(hosp.address) · \(String(format: "%.1f", hosp.distanceMiles)) mi")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.redmedMuted)
                                }
                                Spacer()
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.redmedAccent)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if i < hospitalFinder.hospitals.count - 1 {
                            Divider().overlay(Color.black.opacity(0.06))
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
