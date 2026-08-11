import AVFoundation
import SwiftUI

/// Auto locator siren — Find Help + crash survival alarm.
/// Plays through the silent switch (`.playback`). Crash hold keeps sounding in background.
@MainActor
enum LocatorBeacon {
    private static var activeCount = 0
    /// Crash / hard-impact hold — keeps beeping in background until cancelled.
    private static var survivalHold = false
    private static var timer: Timer?
    private static var player: AVAudioPlayer?
    private static let interval: TimeInterval = 5

    static func begin() {
        activeCount += 1
        guard activeCount == 1 else { return }
        if !survivalHold {
            startRepeating()
        }
    }

    static func end() {
        guard activeCount > 0 else { return }
        activeCount -= 1
        guard activeCount == 0 else { return }
        guard !survivalHold else { return }
        stopRepeating()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Crash motion arm — siren continues while backgrounded until cancelled.
    static func beginSurvival() {
        let wasHeld = survivalHold
        survivalHold = true
        if !wasHeld || timer == nil {
            startRepeating()
        }
    }

    static func endSurvival() {
        guard survivalHold else { return }
        survivalHold = false
        if activeCount == 0 {
            stopRepeating()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// App foregrounded again while Find Help is still up.
    static func resumeIfActive() {
        guard (activeCount > 0 || survivalHold), timer == nil else { return }
        startRepeating()
    }

    /// App backgrounded — stop making noise until we return (unless crash survival hold).
    static func pause() {
        guard !survivalHold else { return }
        guard activeCount > 0 else { return }
        stopRepeating()
    }

    private static func startRepeating() {
        configureSession()
        fire()
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in fire() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private static func stopRepeating() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
    }

    private static func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Session failures stay silent — brightness boost still runs.
        }
    }

    private static func fire() {
        configureSession()
        guard let data = alarmWAV() else { return }
        do {
            let p = try AVAudioPlayer(data: data)
            p.volume = 1.0
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            player = nil
        }
    }

    /// Three piercing beeps (~880 / 1175 / 880 Hz). No bundled asset required.
    private static func alarmWAV() -> Data? {
        let sampleRate = 22050
        let beepDuration = 0.22
        let gapDuration = 0.10
        let frequencies: [Double] = [880, 1174.7, 880]
        var samples: [Int16] = []

        for (i, freq) in frequencies.enumerated() {
            samples.append(contentsOf: tone(frequency: freq, seconds: beepDuration, sampleRate: sampleRate))
            if i < frequencies.count - 1 {
                samples.append(contentsOf: Array(repeating: 0, count: Int(Double(sampleRate) * gapDuration)))
            }
        }

        return pcm16MonoWAV(samples: samples, sampleRate: sampleRate)
    }

    private static func tone(frequency: Double, seconds: Double, sampleRate: Int) -> [Int16] {
        let count = Int(Double(sampleRate) * seconds)
        var out = [Int16]()
        out.reserveCapacity(count)
        let twoPiF = 2.0 * Double.pi * frequency
        for n in 0..<count {
            let t = Double(n) / Double(sampleRate)
            let attack = 0.015
            let release = 0.03
            let env: Double
            if t < attack {
                env = t / attack
            } else if t > seconds - release {
                env = max(0, (seconds - t) / release)
            } else {
                env = 1
            }
            let sample = sin(twoPiF * t) * env * 0.95
            out.append(Int16(max(-1, min(1, sample)) * Double(Int16.max)))
        }
        return out
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

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        appendUInt32(UInt32(36 + dataSize))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
        appendUInt32(16)
        appendUInt16(1) // PCM
        appendUInt16(1) // mono
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2))
        appendUInt16(2)
        appendUInt16(16)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        appendUInt32(UInt32(dataSize))
        for s in samples {
            var le = s.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        return data
    }
}

private struct LocatorBeaconModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isScannerSession) private var isScannerSession

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Passerby / EMS card shell stays quiet — Find Help siren is owner-only.
                guard !isScannerSession else { return }
                LocatorBeacon.begin()
            }
            .onDisappear {
                guard !isScannerSession else { return }
                LocatorBeacon.end()
            }
            .onChange(of: scenePhase) { _, phase in
                guard !isScannerSession else { return }
                switch phase {
                case .active:
                    LocatorBeacon.resumeIfActive()
                case .background:
                    LocatorBeacon.pause()
                default:
                    break
                }
            }
    }
}

extension View {
    /// Auto loud locate-me beep every 5s on owner Find Help (not scanner shell).
    func locatorBeaconEveryFiveSeconds() -> some View {
        modifier(LocatorBeaconModifier())
    }
}
