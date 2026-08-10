import Foundation
import UIKit

/// Local Emergency SOS state machine for Find 911.
/// Online → `telprompt:911`. Offline → Satellite SOS coach (cannot invoke Apple APIs).
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
            dial911()
        }
    }

    private func cancelCountdownTask() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func dial911() {
        guard let url = EmergencySummaryBuilder.call911URL else { return }
        UIApplication.shared.open(url)
    }
}
