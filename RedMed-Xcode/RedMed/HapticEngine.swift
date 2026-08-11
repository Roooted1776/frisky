import CoreHaptics
import Foundation

/// Owns a `CHHapticEngine` for the SwiftUI view hierarchy.
/// Prepare once when the hosting view appears; play calculated patterns on tap / beat.
@MainActor
final class HapticEngine: ObservableObject {
    /// `@AppStorage` / Help → Settings toggle. Default on when unset.
    static let enabledKey = "redmed.hapticsEnabled"

    private var engine: CHHapticEngine?
    private(set) var isReady = false

    var supportsHaptics: Bool {
        #if targetEnvironment(simulator)
        // Taptic Engine is hardware-only — Simulator must still run the app.
        return false
        #else
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #endif
    }

    /// In-app preference (Help → Settings). iOS System Haptics also suppress playback.
    var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// Instantiate and start the engine. Safe to call repeatedly.
    func prepare() {
        guard supportsHaptics, isEnabled else {
            isReady = false
            return
        }
        do {
            if engine == nil {
                let created = try CHHapticEngine()
                created.stoppedHandler = { [weak self] _ in
                    Task { @MainActor in self?.isReady = false }
                }
                created.resetHandler = { [weak self] in
                    Task { @MainActor in
                        do {
                            try self?.engine?.start()
                            self?.isReady = true
                        } catch {
                            self?.isReady = false
                        }
                    }
                }
                engine = created
            }
            try engine?.start()
            isReady = true
        } catch {
            isReady = false
            engine = nil
        }
    }

    /// Sharp compression tap — used on Start and each CPR beat.
    func playCompressionBeat() {
        playTransient(intensity: 1.0, sharpness: 0.9)
    }

    /// Softer cue for the breath phase.
    func playBreathCue() {
        playTransient(intensity: 0.55, sharpness: 0.35)
    }

    /// Calculated transient pattern execution (intensity + sharpness → player).
    private func playTransient(intensity: Float, sharpness: Float) {
        guard supportsHaptics, isEnabled else { return }
        if !isReady { prepare() }
        guard let engine else { return }

        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Engine may have been stopped by the system — try once to recover.
            prepare()
        }
    }
}
