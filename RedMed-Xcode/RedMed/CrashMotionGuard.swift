import CoreMotion
import Foundation
import SwiftUI

/// On-device **vehicle crash / high-speed impact** guard (CoreMotion only).
/// Arms full brightness + locator siren. Ignores running, walking, and daily handling.
/// Not Apple Crash Detection — no GPS/barometer fusion, no cloud.
@MainActor
final class CrashMotionGuard: ObservableObject {
    static let shared = CrashMotionGuard()

    @Published private(set) var isArmed = false

    /// Direct high-speed impact peak (user-acceleration magnitude in g).
    /// Running tops out ~2–4g; desk knocks are lower. Vehicle crashes are far higher.
    private static let crashPeakG: Double = 12.0
    /// After freefall, a slightly lower peak still counts (ejection / vault).
    private static let postFreefallPeakG: Double = 9.0
    /// Near-zero user accel = freefall / ballistic.
    private static let freefallMaxG: Double = 0.35
    private static let freefallMinSeconds: TimeInterval = 0.12
    private static let freefallImpactWindow: TimeInterval = 0.55
    /// Ignore rhythmic mid-g spikes (running / gym).
    private static let activityBandMinG: Double = 1.8
    private static let activityBandMaxG: Double = 6.0
    private static let activitySpikeCount: Int = 3
    private static let activityWindow: TimeInterval = 2.0
    /// Require a sharp onset so slow daily motion never arms.
    private static let minJerkGPerSecond: Double = 80.0
    private static let sampleHz: Double = 50.0
    private static let cooldownSeconds: TimeInterval = 90

    private let manager = CMMotionManager()
    private var freefallSince: Date?
    private var freefallEndedAt: Date?
    private var lastMagnitude: Double = 0
    private var recentActivityPeaks: [Date] = []
    private var lastArmAt: Date?
    private var isMonitoring = false

    private init() {}

    /// Start after first paint so cold launch stays light.
    func startMonitoring() {
        guard !isMonitoring else { return }
        guard manager.isDeviceMotionAvailable else { return }
        isMonitoring = true
        resetTransientState()
        manager.deviceMotionUpdateInterval = 1.0 / Self.sampleHz
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.evaluate(userAcceleration: motion.userAcceleration)
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        manager.stopDeviceMotionUpdates()
        resetTransientState()
    }

    /// False-positive cancel — restores brightness/siren holds.
    func disarm() {
        guard isArmed else { return }
        isArmed = false
        BrightnessBoost.endSurvival()
        LocatorBeacon.endSurvival()
    }

    private func arm() {
        guard !isArmed else { return }
        isArmed = true
        lastArmAt = Date()
        resetTransientState()
        BrightnessBoost.beginSurvival()
        LocatorBeacon.beginSurvival()
    }

    private func resetTransientState() {
        freefallSince = nil
        freefallEndedAt = nil
        lastMagnitude = 0
        recentActivityPeaks.removeAll(keepingCapacity: true)
    }

    private func evaluate(userAcceleration accel: CMAcceleration) {
        if isArmed { return }
        if let last = lastArmAt, Date().timeIntervalSince(last) < Self.cooldownSeconds {
            return
        }

        let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        let dt = 1.0 / Self.sampleHz
        let jerk = abs(magnitude - lastMagnitude) / dt
        lastMagnitude = magnitude

        // Track mid-band spikes — running produces several per second.
        let now = Date()
        if magnitude >= Self.activityBandMinG && magnitude <= Self.activityBandMaxG {
            recentActivityPeaks.append(now)
        }
        recentActivityPeaks.removeAll { now.timeIntervalSince($0) > Self.activityWindow }
        if recentActivityPeaks.count >= Self.activitySpikeCount {
            // Active locomotion / daily bounce — never arm from this window.
            freefallSince = nil
            freefallEndedAt = nil
            return
        }

        // Freefall tracking (airborne then slam).
        if magnitude <= Self.freefallMaxG {
            if freefallSince == nil { freefallSince = now }
        } else if let since = freefallSince {
            if now.timeIntervalSince(since) >= Self.freefallMinSeconds {
                freefallEndedAt = now
            }
            freefallSince = nil
        }

        let inPostFreefallWindow: Bool = {
            guard let ended = freefallEndedAt else { return false }
            if now.timeIntervalSince(ended) > Self.freefallImpactWindow {
                freefallEndedAt = nil
                return false
            }
            return true
        }()

        // Must be a sharp onset — filters slow daily lean / pocket shift.
        guard jerk >= Self.minJerkGPerSecond else { return }

        if magnitude >= Self.crashPeakG {
            arm()
            return
        }

        if inPostFreefallWindow, magnitude >= Self.postFreefallPeakG {
            arm()
        }
    }
}

/// Cancel card shown on Aid / Find Help while crash survival alarm is armed.
/// Matches pane / InfoCard chrome (surface + divider stroke).
struct CrashSurvivalCancelCard: View {
    @ObservedObject private var monitor = CrashMotionGuard.shared

    var body: some View {
        if monitor.isArmed {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "light.beacon.max.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.redmedAccent)
                        .frame(width: 28, height: 28)
                        .background(Color.redmedAccent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Crash / high-speed impact")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.redmedDark)
                        Text("Full brightness + locate-me siren are on. Local sensors only — not running or daily motion.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.redmedMuted)
                    }
                }

                Button {
                    monitor.disarm()
                } label: {
                    Text("I'm OK — cancel alarm")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 1, green: 0.447, blue: 0.537), .redmedAccent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.redmedAccent.opacity(0.28), radius: 7, y: 4)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.redmedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.redmedAccent.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }
}
