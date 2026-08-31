import AVFoundation
import CoreHaptics
import Foundation
import UIKit

/// Light UIKit taps shared by tabs / chrome / SOS / Aid. Respects the haptic toggle.
enum RedMedHaptics {
    /// `@AppStorage` / Before you continue toggle. Default on when unset.
    /// Lives here (not on `@MainActor` `HapticEngine`) so nonisolated callers stay clean under Swift 6.
    static let enabledKey = "redmed.hapticsEnabled"

    private static var enabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Reused generators — `UI*FeedbackGenerator()` + fire on every tab tap
    /// hitches while Taptic Engine warms a brand-new client.
    private static let selectionGen = UISelectionFeedbackGenerator()
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private static let notifyGen = UINotificationFeedbackGenerator()

    /// Warm the Taptic clients before the first tab press.
    static func prepare() {
        guard enabled else { return }
        selectionGen.prepare()
        lightGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
        notifyGen.prepare()
    }

    static func selection() {
        guard enabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    static func light() {
        guard enabled else { return }
        lightGen.impactOccurred()
        lightGen.prepare()
    }

    static func medium() {
        guard enabled else { return }
        mediumGen.impactOccurred()
        mediumGen.prepare()
    }

    static func heavy() {
        guard enabled else { return }
        heavyGen.impactOccurred()
        heavyGen.prepare()
    }

    static func error() {
        guard enabled else { return }
        notifyGen.notificationOccurred(.error)
        notifyGen.prepare()
    }

    static func success() {
        guard enabled else { return }
        notifyGen.notificationOccurred(.success)
        notifyGen.prepare()
    }
}

/// Owns a `CHHapticEngine` + short CPR metronome clicks for the SwiftUI view hierarchy.
/// Prepare once when the hosting view appears; play calculated patterns on tap / beat.
/// Audio clicks use `.playback` + mixWithOthers so they work with the silent switch
/// without stealing the crash / SOS locator siren session (siren retains at
/// `AudioSessionGate.survivalPriority` and wins category options).
@MainActor
final class HapticEngine: ObservableObject {
    private static let sessionClient = "cpr-metronome"

    private var engine: CHHapticEngine?
    private(set) var isReady = false
    /// Player confined to `AudioSessionGate.queue` — never touch from MainActor.
    private let clickPlayer = ClickPlayerBox()
    private var audioSessionReady = false
    private var audioEpoch = 0

    var supportsHaptics: Bool {
        #if targetEnvironment(simulator)
        // Taptic Engine is hardware-only — Simulator must still run the app.
        return false
        #else
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #endif
    }

    /// In-app preference (Before you continue). iOS System Haptics also suppress playback.
    var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: RedMedHaptics.enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: RedMedHaptics.enabledKey)
    }

    /// Instantiate and start the engine. Safe to call repeatedly.
    func prepare() {
        prepareAudioSession()
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

    /// Release audio when leaving the CPR card.
    func shutdown() {
        audioEpoch &+= 1
        audioSessionReady = false
        let box = clickPlayer
        AudioSessionGate.queue.async {
            box.player?.stop()
            box.player = nil
        }
        AudioSessionGate.release(client: Self.sessionClient)
    }

    /// Sharp compression tap — used on Start and each CPR beat.
    func playCompressionBeat() {
        playTransient(intensity: 1.0, sharpness: 0.9)
        playTone(frequency: 1046.5, seconds: 0.045, volume: 0.85)
    }

    /// Softer cue for the breath phase.
    func playBreathCue() {
        playTransient(intensity: 0.55, sharpness: 0.35)
        playTone(frequency: 698.5, seconds: 0.18, volume: 0.55)
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

    private func prepareAudioSession() {
        audioEpoch &+= 1
        let epoch = audioEpoch
        AudioSessionGate.retain(client: Self.sessionClient, options: [.mixWithOthers]) {
            Task { @MainActor in
                guard epoch == self.audioEpoch else { return }
                self.audioSessionReady = true
            }
        }
    }

    private func playTone(frequency: Double, seconds: Double, volume: Float) {
        if !audioSessionReady { prepareAudioSession() }
        guard let data = Self.clickWAV(frequency: frequency, seconds: seconds) else { return }
        let box = clickPlayer
        // create / prepareToPlay / play all stay on the gate queue.
        AudioSessionGate.queue.async {
            box.player?.stop()
            do {
                let player = try AVAudioPlayer(data: data)
                player.volume = volume
                player.prepareToPlay()
                player.play()
                box.player = player
            } catch {
                box.player = nil
            }
        }
    }

    private static func clickWAV(frequency: Double, seconds: Double) -> Data? {
        let sampleRate = 22050
        let count = Int(Double(sampleRate) * seconds)
        var samples = [Int16]()
        samples.reserveCapacity(count)
        let twoPiF = 2.0 * Double.pi * frequency
        for n in 0..<count {
            let t = Double(n) / Double(sampleRate)
            let attack = 0.004
            let release = 0.012
            let env: Double
            if t < attack {
                env = t / attack
            } else if t > seconds - release {
                env = max(0, (seconds - t) / release)
            } else {
                env = 1
            }
            let sample = sin(twoPiF * t) * env * 0.9
            samples.append(Int16(max(-1, min(1, sample)) * Double(Int16.max)))
        }
        return PCMAudio.wavData(samples: samples, sampleRate: sampleRate)
    }
}

/// Queue-confined click player — only touch from `AudioSessionGate.queue`.
private final class ClickPlayerBox: @unchecked Sendable {
    var player: AVAudioPlayer?
}
