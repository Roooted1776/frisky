import Foundation
import UIKit

/// Local Emergency SOS state machine for Find 911.
/// Online → caller-supplied outbound (third-party API + dial + SMS).
/// Offline → Satellite SOS coach (cannot invoke Apple Satellite SOS APIs).
@MainActor
final class EmergencySOSController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case countdown
        case satelliteCoach
    }

    static let countdownSeconds = 8

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var secondsRemaining: Int = countdownSeconds

    private var countdownTask: Task<Void, Never>?
    /// Fresh offline check at fire time (set by Find 911).
    var isOfflineCheck: () -> Bool = { false }
    /// Online fire hook — LocationView posts to third-party API, dials 911, opens SMS.
    /// Default keeps prior behavior: `telprompt:911` only.
    var onOnlineFire: () -> Void = {
        guard let url = EmergencySummaryBuilder.call911URL else { return }
        UIApplication.shared.open(url)
    }

    var isCountingDown: Bool { phase == .countdown }
    var showsSatelliteCoach: Bool { phase == .satelliteCoach }

    /// Starts a cancelable countdown, then dials 911 or opens the satellite coach.
    /// `isOffline` documents the UI state at tap time; completion uses `isOfflineCheck`.
    func startCountdown(isOffline _: Bool) {
        cancelCountdownTask()
        phase = .countdown
        secondsRemaining = Self.countdownSeconds
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for remaining in stride(from: Self.countdownSeconds, through: 1, by: -1) {
                if Task.isCancelled { return }
                self.secondsRemaining = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if Task.isCancelled { return }
            self.finish(isOffline: self.isOfflineCheck())
        }
    }

    func cancel() {
        cancelCountdownTask()
        phase = .idle
        secondsRemaining = Self.countdownSeconds
    }

    func dismissSatelliteCoach() {
        phase = .idle
    }

    /// Immediate fire without countdown (seizure 5‑minute threshold, “Call now”).
    func fireNow(isOffline: Bool) {
        cancelCountdownTask()
        finish(isOffline: isOffline)
    }

    private func finish(isOffline: Bool) {
        if isOffline {
            phase = .satelliteCoach
        } else {
            phase = .idle
            onOnlineFire()
        }
    }

    private func cancelCountdownTask() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}
