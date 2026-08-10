import Combine
import Network

/// On-device connectivity only — no network requests. Used on Find 911 to
/// show factual satellite-SOS guidance when the phone has no usable path.
/// Start explicitly after first paint — do not begin NWPathMonitor in `init`.
final class NetworkPathMonitor: ObservableObject {
    @Published private(set) var isOffline = false

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "local.redmed.network")

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }

    deinit {
        monitor?.cancel()
    }
}
