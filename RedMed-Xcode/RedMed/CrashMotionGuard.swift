import CoreMotion
import Foundation
import SwiftUI

/// On-device **vehicle crash / high-speed impact** guard (CoreMotion only).
/// Arms full brightness + locator siren. Ignores running, walking, wrist flicks,
/// and daily handling. Not Apple Crash Detection — no GPS/barometer fusion, no cloud.
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

/// Cancel control on Aid — under panes, above the quote.
/// Sized like a full-width pane card; CTA matches open-pane topic rows.
struct CrashSurvivalCancelCard: View {
    @ObservedObject private var monitor = CrashMotionGuard.shared

    var body: some View {
        if monitor.isArmed {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "light.beacon.max.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.redmedAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Crash / high-speed impact")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.redmedAccent)
                            .lineLimit(2)
                        Text("Siren + full brightness on — local sensors only")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.redmedMuted)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(13)
                .frame(minHeight: 96, alignment: .top)

                Button {
                    monitor.disarm()
                } label: {
                    HStack {
                        Text("I'm OK — cancel alarm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedDark)
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.redmedAccent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.redmedDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
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
