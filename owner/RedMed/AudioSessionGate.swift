import AVFoundation
import Foundation

/// Single serial gate for blocking `AVAudioSession` work.
/// `setCategory` / `setActive` / `outputVolume` must never run on the main thread
/// (Xcode Thread Performance Checker: AVAudioSession Hang Risk).
enum AudioSessionGate {
    static let queue = DispatchQueue(label: "redmed.audio-session")

    /// SOS / crash siren outranks CPR metronome so mixWithOthers cannot steal the route.
    static let survivalPriority = 100
    static let defaultPriority = 0

    /// Clients that currently need an active playback session (queue-only).
    private static var clients: [String: Client] = [:]
    private static var lastOptions: AVAudioSession.CategoryOptions?
    private static var lastPriority: Int?

    private struct Client {
        var options: AVAudioSession.CategoryOptions
        var priority: Int
    }

    /// Keep the session active for `client`. Idempotent per client.
    /// Highest `priority` wins category options (survival siren beats CPR mix).
    /// `onReady` runs on this gate's queue after activate succeeds (or session already up).
    static func retain(
        client: String,
        options: AVAudioSession.CategoryOptions,
        priority: Int = defaultPriority,
        onReady: (@Sendable () -> Void)? = nil
    ) {
        queue.async {
            clients[client] = Client(options: options, priority: priority)
            applyBest(force: true)
            onReady?()
        }
    }

    /// Re-apply category + active for an existing client.
    /// Bluetooth drop / headphone unplug / audio switch: SOS reclaims the route.
    static func reassert(client: String, onReady: (@Sendable () -> Void)? = nil) {
        queue.async {
            guard clients[client] != nil else {
                onReady?()
                return
            }
            applyBest(force: true)
            onReady?()
        }
    }

    /// Drop `client`. Deactivates only when nobody else still holds the session.
    static func release(client: String) {
        queue.async {
            clients.removeValue(forKey: client)
            guard !clients.isEmpty else {
                lastOptions = nil
                lastPriority = nil
                try? AVAudioSession.sharedInstance().setActive(
                    false,
                    options: .notifyOthersOnDeactivation
                )
                return
            }
            applyBest(force: true)
        }
    }

    /// Must run on `queue`. Re-activates without changing category.
    static func activateOnQueue() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func readOutputVolume(_ body: @escaping @Sendable (Float) -> Void) {
        queue.async {
            body(AVAudioSession.sharedInstance().outputVolume)
        }
    }

    /// Install KVO for system volume changes. Observation handed back on the gate queue.
    static func observeOutputVolume(
        _ handler: @escaping @Sendable (Float) -> Void,
        ready: @escaping @Sendable (NSKeyValueObservation) -> Void
    ) {
        queue.async {
            let observation = AVAudioSession.sharedInstance().observe(
                \.outputVolume,
                options: [.new]
            ) { _, change in
                guard let value = change.newValue else { return }
                handler(value)
            }
            ready(observation)
        }
    }

    /// Queue-only. Highest-priority client's options become the live session.
    private static func applyBest(force: Bool) {
        guard let best = clients.max(by: { $0.value.priority < $1.value.priority })?.value else {
            return
        }
        let session = AVAudioSession.sharedInstance()
        let optionsChanged = lastOptions != best.options || lastPriority != best.priority
        do {
            if force || optionsChanged {
                // Exclusive `.playback` (no mixWithOthers) interrupts other apps
                // so SOS Locate Me takes the audio.
                try session.setCategory(.playback, mode: .default, options: best.options)
                lastOptions = best.options
                lastPriority = best.priority
            }
            // Always re-assert active — Stop then re-arm, and BT route flips,
            // can race a prior deactivate or leave the session inert.
            try session.setActive(true)
        } catch {
            // Session failures stay silent — brightness / UI still run.
        }
    }
}

/// Shared WAV encoding for the small in-memory tones `HapticEngine` and
/// `LocatorBeacon` synthesize on-device (click feedback, survival-alarm siren).
enum PCMAudio {
    /// Wraps 16-bit mono PCM samples in a minimal RIFF/WAVE header.
    nonisolated static func wavData(samples: [Int16], sampleRate: Int) -> Data {
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
