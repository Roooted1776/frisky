import AVFoundation
import Foundation

/// Single serial gate for blocking `AVAudioSession` work.
/// `setCategory` / `setActive` / `outputVolume` must never run on the main thread
/// (Xcode Thread Performance Checker: AVAudioSession Hang Risk).
enum AudioSessionGate {
    static let queue = DispatchQueue(label: "redmed.audio-session")

    /// Activate `.playback` with the given options. `onReady` runs on this gate's queue.
    static func activatePlayback(
        options: AVAudioSession.CategoryOptions,
        onReady: @escaping () -> Void
    ) {
        queue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: options)
                try session.setActive(true)
                onReady()
            } catch {
                // Session failures stay silent — brightness / UI still run.
            }
        }
    }

    static func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    static func readOutputVolume(_ body: @escaping (Float) -> Void) {
        queue.async {
            body(AVAudioSession.sharedInstance().outputVolume)
        }
    }

    /// Install KVO for system volume changes. Observation object is returned on the gate queue.
    static func observeOutputVolume(
        _ handler: @escaping (Float) -> Void,
        ready: @escaping (NSKeyValueObservation) -> Void
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
}
