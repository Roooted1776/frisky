import Combine
import Network

/// On-device connectivity only — no network requests. Used on Find 911 to
/// show factual satellite-SOS guidance when the phone has no usable path.
final class NetworkPathMonitor: ObservableObject {
    @Published private(set) var isOffline = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "local.redmed.network")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
