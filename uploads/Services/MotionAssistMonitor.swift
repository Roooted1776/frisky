import CoreMotion
import Foundation

/// Opt-in, Find-911-visible-only motion assist.
/// Conservative high-g / sustained-shake heuristic — assistive, not diagnosis.
/// Not Apple Crash Detection.
@MainActor
final class MotionAssistMonitor: ObservableObject {
    @Published var isEnabled = false
    @Published private(set) var didTrigger = false

    /// User-acceleration magnitude (g) that counts as a hard jolt.
    private static let peakThresholdG: Double = 2.8
    /// How long sustained elevated motion must persist (seconds).
    private static let sustainSeconds: TimeInterval = 1.2
    /// Cool-down after a trigger so we don't re-fire while still shaking.
    private static let cooldownSeconds: TimeInterval = 30

    private let manager = CMMotionManager()
    private var elevatedSince: Date?
    private var lastTriggerAt: Date?
    private var isRunning = false

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    /// Call when Find 911 appears and the toggle is on.
    func start() {
        guard isEnabled, !isRunning else { return }
        guard manager.isDeviceMotionAvailable else { return }
        isRunning = true
        elevatedSince = nil
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion, self.isEnabled else { return }
            self.evaluate(userAcceleration: motion.userAcceleration)
        }
    }

    /// Call when Find 911 disappears — same battery rule as GPS.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
        elevatedSince = nil
    }

    func consumeTrigger() {
        didTrigger = false
    }

    private func evaluate(userAcceleration accel: CMAcceleration) {
        if let last = lastTriggerAt, Date().timeIntervalSince(last) < Self.cooldownSeconds {
            return
        }

        let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        if magnitude >= Self.peakThresholdG {
            if elevatedSince == nil {
                elevatedSince = Date()
            } else if let since = elevatedSince,
                      Date().timeIntervalSince(since) >= Self.sustainSeconds {
                elevatedSince = nil
                lastTriggerAt = Date()
                didTrigger = true
            }
        } else {
            elevatedSince = nil
        }
    }
}
