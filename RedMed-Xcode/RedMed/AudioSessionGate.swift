import AVFoundation
import Foundation

/// Single serial gate for blocking `AVAudioSession` work.
/// `setCategory` / `setActive` / `outputVolume` must never run on the main thread
/// (Xcode Thread Performance Checker: AVAudioSession Hang Risk).
enum AudioSessionGate {
    static let queue = DispatchQueue(label: "redmed.audio-session")

    /// Clients that currently need an active playback session (queue-only).
    private static var clients: Set<String> = []
    private static var lastOptions: AVAudioSession.CategoryOptions?

    /// Keep the session active for `client`. Idempotent per client.
    /// `onReady` runs on this gate's queue after activate succeeds (or session already up).
    static func retain(
        client: String,
        options: AVAudioSession.CategoryOptions,
        onReady: (@Sendable () -> Void)? = nil
    ) {
        queue.async {
            let wasEmpty = clients.isEmpty
            clients.insert(client)
            let optionsChanged = lastOptions != options
            lastOptions = options

            let session = AVAudioSession.sharedInstance()
            do {
                if wasEmpty || optionsChanged {
                    try session.setCategory(.playback, mode: .default, options: options)
                }
                // Always re-assert active — Stop/Reset then re-arm can race a prior deactivate.
                try session.setActive(true)
            } catch {
                // Session failures stay silent — brightness / UI still run.
                onReady?()
                return
            }
            onReady?()
        }
    }

    /// Drop `client`. Deactivates only when nobody else still holds the session.
    static func release(client: String) {
        queue.async {
            clients.remove(client)
            guard clients.isEmpty else { return }
            lastOptions = nil
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
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
}
