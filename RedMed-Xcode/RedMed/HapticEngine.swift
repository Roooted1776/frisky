import AVFoundation
import CoreHaptics
import Foundation
import UIKit

/// Light UIKit taps shared by tabs / chrome / SOS / Aid. Respects Help → Settings.
enum RedMedHaptics {
    /// `@AppStorage` / Help → Settings toggle. Default on when unset.
    /// Lives here (not on `@MainActor` `HapticEngine`) so nonisolated callers stay clean under Swift 6.
    static let enabledKey = "redmed.hapticsEnabled"

    private static var enabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Owns a `CHHapticEngine` + short CPR metronome clicks for the SwiftUI view hierarchy.
/// Prepare once when the hosting view appears; play calculated patterns on tap / beat.
/// Audio clicks use `.playback` + mixWithOthers so they work with the silent switch
/// without stealing the crash / SOS locator siren session.
@MainActor
final class HapticEngine: ObservableObject {
    private var engine: CHHapticEngine?
    private(set) var isReady = false
    private var audioPlayer: AVAudioPlayer?
    private var audioSessionReady = false
    private let audioSessionQueue = DispatchQueue(label: "redmed.cpr-metronome.session")
    private var audioEpoch = 0

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
        audioPlayer?.stop()
        audioPlayer = nil
        audioSessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
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
        audioSessionQueue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
            } catch {
                return
            }
            Task { @MainActor in
                guard epoch == self.audioEpoch else { return }
                self.audioSessionReady = true
            }
        }
    }

    private func playTone(frequency: Double, seconds: Double, volume: Float) {
        if !audioSessionReady { prepareAudioSession() }
        guard let data = Self.clickWAV(frequency: frequency, seconds: seconds) else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            audioPlayer = nil
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
        return pcm16MonoWAV(samples: samples, sampleRate: sampleRate)
    }

    private static func pcm16MonoWAV(samples: [Int16], sampleRate: Int) -> Data {
        let dataSize = samples.count * 2
        var data = Data()
        func appendUInt32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendUInt16(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        appendUInt32(UInt32(36 + dataSize))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2))
        appendUInt16(2)
        appendUInt16(16)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        appendUInt32(UInt32(dataSize))
        for s in samples {
            var le = s.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        return data
    }
}
