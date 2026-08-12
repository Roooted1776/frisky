import AVFoundation

/// Survival siren for crash / severe-impact or Find Help SOS (owner + tapper).
/// Plays through the silent switch (`.playback`) and keeps sounding in background until cancelled.
/// System volume is forced to max by `VolumeBoost` for the same survival hold.
@MainActor
enum LocatorBeacon {
    private static let sessionClient = "locator-beacon"

    private static var survivalHold = false
    private static var timer: Timer?
    /// Synth once — re-building PCM every 5s hitch on the main thread while SOS is armed.
    private static var cachedAlarmWAV: Data?
    private static let interval: TimeInterval = 5
    /// Bumped on prepare / end so late activate callbacks cannot arm after cancel.
    private static var sessionEpoch = 0
    private static var sessionReady = false

    /// Player is confined to `AudioSessionGate.queue` — never touch from MainActor.
    private static let siren = SirenPlayerBox()

    /// Survival arm — siren continues while backgrounded until cancelled.
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
        sessionReady = false
        sessionEpoch &+= 1
        stopRepeating()
        AudioSessionGate.release(client: sessionClient)
    }

    private static func startRepeating() {
        prepareSessionThenArm()
    }

    private static func stopRepeating() {
        timer?.invalidate()
        timer = nil
        let box = siren
        AudioSessionGate.queue.async {
            box.player?.stop()
            box.player = nil
        }
    }

    private static func prepareSessionThenArm() {
        sessionEpoch &+= 1
        let epoch = sessionEpoch
        sessionReady = false
        timer?.invalidate()
        timer = nil

        let wav = alarmWAV()
        let box = siren

        AudioSessionGate.retain(client: sessionClient, options: [.duckOthers]) {
            box.player?.stop()
            box.player = nil
            if let wav {
                let prepared = try? AVAudioPlayer(data: wav)
                prepared?.volume = 1.0
                prepared?.prepareToPlay()
                box.player = prepared
            }
            Task { @MainActor in
                guard Self.survivalHold, epoch == Self.sessionEpoch else {
                    AudioSessionGate.release(client: sessionClient)
                    AudioSessionGate.queue.async {
                        box.player?.stop()
                        box.player = nil
                    }
                    return
                }
                Self.sessionReady = true
                Self.fire()
                Self.armTimer()
            }
        }
    }

    private static func armTimer() {
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in fire() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private static func fire() {
        guard survivalHold, sessionReady else { return }
        let box = siren
        AudioSessionGate.queue.async {
            guard let player = box.player else { return }
            player.currentTime = 0
            player.volume = 1.0
            player.play()
        }
    }

    /// Three piercing beeps (~880 / 1175 / 880 Hz). No bundled asset required.
    private static func alarmWAV() -> Data? {
        if let cachedAlarmWAV { return cachedAlarmWAV }
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

        let data = pcm16MonoWAV(samples: samples, sampleRate: sampleRate)
        cachedAlarmWAV = data
        return data
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

/// Queue-confined `AVAudioPlayer` holder — only touch from `AudioSessionGate.queue`.
private final class SirenPlayerBox: @unchecked Sendable {
    var player: AVAudioPlayer?
}
