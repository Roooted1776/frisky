import SwiftUI
import AVFoundation
import AudioToolbox

/// Hands-only CPR metronome (~110 BPM).
struct CPRTimerView: View {
    @Environment(\.layoutMetrics) private var layout

    var embedded: Bool = false

    private static let bpm: Double = 110
    private static let intervalNs: UInt64 = UInt64((60.0 / bpm) * 1_000_000_000)

    @State private var isRunning = false
    @State private var soundOn = false
    @State private var elapsed: TimeInterval = 0
    @State private var pulse = false
    @State private var startedAt: Date?
    @State private var accumulated: TimeInterval = 0
    @State private var beatTask: Task<Void, Never>?
    @State private var clockTask: Task<Void, Never>?

    private let haptics = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        let content = VStack(spacing: layout.spaceMD) {
            Circle()
                .fill(AppTheme.accent)
                .frame(width: layout.cprPulse, height: layout.cprPulse)
                .scaleEffect(pulse ? 1.14 : 1)
                .animation(.easeOut(duration: 0.08), value: pulse)

            Text(isRunning ? "Push hard & fast" : "Compress on beat")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isRunning ? AppTheme.ink : AppTheme.muted)

            Text(formatElapsed(elapsed))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: layout.spaceSM) {
                Button(isRunning ? "Stop" : "Start") {
                    if isRunning { stop() } else { start() }
                }
                .buttonStyle(PrimaryButtonStyle(prominent: true))

                Button("Reset") { reset() }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: layout.cprResetMaxWidth)
            }

            Toggle("Sound", isOn: $soundOn)
                .font(.subheadline)
                .tint(AppTheme.accent)
                .onChange(of: soundOn) { on in
                    guard on else { return }
                    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, embedded ? layout.spaceSM : layout.spaceLG)

        Group {
            if embedded {
                content
            } else {
                content
                    .padding(layout.spaceLG)
                    .appCard()
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        haptics.prepare()
        if soundOn {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        isRunning = true
        startedAt = Date()
        fireBeat()

        beatTask?.cancel()
        beatTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.intervalNs)
                guard !Task.isCancelled else { return }
                fireBeat()
            }
        }

        clockTask?.cancel()
        clockTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, let startedAt else { return }
                elapsed = accumulated + Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func stop() {
        if let startedAt {
            accumulated += Date().timeIntervalSince(startedAt)
            elapsed = accumulated
        }
        self.startedAt = nil
        isRunning = false
        beatTask?.cancel()
        clockTask?.cancel()
        beatTask = nil
        clockTask = nil
        pulse = false
    }

    private func reset() {
        stop()
        accumulated = 0
        elapsed = 0
    }

    private func fireBeat() {
        pulse = true
        haptics.impactOccurred()
        if soundOn { AudioServicesPlaySystemSound(1104) }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            pulse = false
        }
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            CPRTimerView()
            CPRTimerView(embedded: true)
                .padding()
                .appCard()
        }
        .padding()
    }
    .background(AppTheme.pageBg)
    .withLayoutMetrics()
}
