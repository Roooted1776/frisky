import AVFoundation

/// Survival siren for crash / severe-impact or Find Help SOS (owner + tapper).
/// Plays through the silent switch (`.playback`) and keeps sounding in background until cancelled.
/// Exclusive session — SOS Locate Me interrupts other apps and reclaims the
/// route when Bluetooth drops or audio switches (headphones, CarPlay, AirPlay).
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
    private static var sessionEpoch: UInt64 = 0
    private static var sessionReady = false
    /// Debounce BT disconnect / interruption bursts so a late reclaim cannot
    /// restart the siren after Stop.
    private static var reclaimGeneration: UInt64 = 0

    private static var routeObserver: NSObjectProtocol?
    private static var interruptionObserver: NSObjectProtocol?
    private static var mediaResetObserver: NSObjectProtocol?

    /// Published for gate-queue stale checks (same value as `sessionEpoch`).
    private static let publishedEpoch = EpochBox()
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

    /// Synth the WAV off the SOS hot path (unlock / crash monitor start).
    static func warmAlarmCache() {
        if cachedAlarmWAV != nil { return }
        Task.detached(priority: .utility) {
            let data = Self.synthesizeAlarmWAV()
            await MainActor.run {
                if cachedAlarmWAV == nil {
                    cachedAlarmWAV = data
                }
            }
        }
    }

    static func endSurvival() {
        guard survivalHold else { return }
        survivalHold = false
        sessionReady = false
        sessionEpoch &+= 1
        reclaimGeneration &+= 1
        publishedEpoch.value = sessionEpoch
        removeRouteWatch()
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
        publishedEpoch.value = epoch
        sessionReady = false
        timer?.invalidate()
        timer = nil

        let wav = alarmWAV()
        let box = siren
        let epochBox = publishedEpoch

        // Exclusive `.playback` (empty options) — interrupt other apps, take the
        // output. mixWithOthers / CPR cannot override (survivalPriority).
        AudioSessionGate.retain(
            client: sessionClient,
            options: [],
            priority: AudioSessionGate.survivalPriority
        ) {
            // Stale prepare — newer arm/end owns the session. Do not release or nil
            // the player (that was wiping sound after Stop → SOS again).
            guard epochBox.value == epoch else { return }

            box.player?.stop()
            box.player = nil
            if let wav {
                let prepared = try? AVAudioPlayer(data: wav)
                prepared?.volume = 1.0
                prepared?.numberOfLoops = 0
                prepared?.prepareToPlay()
                box.player = prepared
            }

            Task { @MainActor in
                // Epoch mismatch / disarmed: endSurvival already released. Do nothing.
                guard Self.survivalHold, epoch == Self.sessionEpoch else { return }
                Self.sessionReady = true
                Self.installRouteWatch()
                Self.fire()
                Self.armTimer()
            }
        }
    }

    /// Bluetooth disconnect, headphone unplug, CarPlay / AirPlay switch, and
    /// session interruptions pause AVAudioPlayer. Reclaim the route and fire.
    private static func installRouteWatch() {
        removeRouteWatch()
        let center = NotificationCenter.default
        routeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                Self.handleRouteChange()
            }
        }
        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                Self.handleInterruption(rawType: raw)
            }
        }
        mediaResetObserver = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard Self.survivalHold else { return }
                Self.reclaimAudio()
            }
        }
    }

    private static func removeRouteWatch() {
        let center = NotificationCenter.default
        if let routeObserver {
            center.removeObserver(routeObserver)
            self.routeObserver = nil
        }
        if let interruptionObserver {
            center.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        if let mediaResetObserver {
            center.removeObserver(mediaResetObserver)
            self.mediaResetObserver = nil
        }
    }

    private static func handleRouteChange() {
        guard survivalHold else { return }
        // oldDeviceUnavailable = BT / headphones gone. newDeviceAvailable =
        // AirPods / CarPlay / speaker switch. Either way SOS takes the new route.
        reclaimAudio()
    }

    private static func handleInterruption(rawType: UInt?) {
        guard survivalHold else { return }
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            reclaimAudio()
            return
        }
        if type == .ended {
            reclaimAudio()
        }
        // `.began` — system paused us (call / Siri). Stay armed; resume on `.ended`.
    }

    /// Debounced re-activate + siren burst. Route flips often fire in a cluster.
    private static func reclaimAudio() {
        guard survivalHold else { return }
        reclaimGeneration &+= 1
        let gen = reclaimGeneration
        let epoch = sessionEpoch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard gen == Self.reclaimGeneration, Self.survivalHold, epoch == Self.sessionEpoch else {
                return
            }
            AudioSessionGate.reassert(client: sessionClient) {
                Task { @MainActor in
                    guard gen == Self.reclaimGeneration, Self.survivalHold, epoch == Self.sessionEpoch else {
                        return
                    }
                    Self.sessionReady = true
                    Self.fire()
                }
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
        // Fresh player each burst — reusing one AVAudioPlayer only sounded on the
        // first Start; later timer fires (and Stop → SOS again) were silent.
        guard let wav = alarmWAV() else { return }
        let box = siren
        let epoch = sessionEpoch
        let epochBox = publishedEpoch
        AudioSessionGate.queue.async {
            guard epochBox.value == epoch else { return }
            AudioSessionGate.activateOnQueue()
            box.player?.stop()
            guard let player = try? AVAudioPlayer(data: wav) else {
                box.player = nil
                return
            }
            player.volume = 1.0
            player.prepareToPlay()
            box.player = player
            _ = player.play()
        }
    }

    /// Three piercing beeps (~880 / 1175 / 880 Hz). No bundled asset required.
    private static func alarmWAV() -> Data? {
        if let cachedAlarmWAV { return cachedAlarmWAV }
        let data = synthesizeAlarmWAV()
        cachedAlarmWAV = data
        return data
    }

    /// Pure synth — safe off MainActor for `warmAlarmCache`.
    nonisolated private static func synthesizeAlarmWAV() -> Data {
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

        return PCMAudio.wavData(samples: samples, sampleRate: sampleRate)
    }

    nonisolated private static func tone(frequency: Double, seconds: Double, sampleRate: Int) -> [Int16] {
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
}

/// Queue-confined `AVAudioPlayer` holder — only touch from `AudioSessionGate.queue`.
private final class SirenPlayerBox: @unchecked Sendable {
    var player: AVAudioPlayer?
}

/// Written on MainActor, read from `AudioSessionGate.queue` — lock-guarded so a
/// stale-epoch check on that queue always sees the latest arm/end, not a torn
/// or cached read (matches `TapCardPresentation`'s cross-thread bool pattern).
private final class EpochBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: UInt64 = 0

    var value: UInt64 {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            _value = newValue
            lock.unlock()
        }
    }
}
