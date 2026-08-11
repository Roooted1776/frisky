import CryptoKit
import Foundation
import CoreBluetooth
import Security

// MARK: - Payload sizing

enum SatellitePayloadSizer {
    static func utf8ByteCount(_ text: String) -> Int {
        text.utf8.count
    }

    static func isOverSoftLimit(_ text: String) -> Bool {
        utf8ByteCount(text) > AppConfig.Satellite.softPayloadBytes
    }

    static func isOverHardLimit(_ text: String) -> Bool {
        utf8ByteCount(text) > AppConfig.Satellite.hardPayloadBytes
    }
}

// MARK: - Encryption wrapper (interceptor)

/// Seals plaintext **immediately before** handoff to the satellite transport.
/// Does not rewrite `ProfileData` / Keychain models — inject only on the outbound path.
///
/// CryptoKit AES-GCM requires iOS 13+. RedMed’s deployment target is already 17.0,
/// so no `#available` gate is required at call sites.
enum SatelliteCryptoInterceptor {
    private static let keyAccount = "satellite.outbound.aes.v1"
    private static let keyService = "com.redmed.app.satellite"

    /// Versioned sealed blob: `0x01 || nonce(12) || ciphertext+tag`.
    private static let version: UInt8 = 0x01

    struct SealedPacket: Equatable {
        let ciphertext: Data
        let plaintextByteCount: Int
    }

    enum InterceptError: LocalizedError {
        case empty
        case overHardLimit(Int)
        case sealFailed

        var errorDescription: String? {
            switch self {
            case .empty:
                return "Nothing to send."
            case .overHardLimit(let n):
                return "Payload is \(n) bytes; max is \(AppConfig.Satellite.hardPayloadBytes)."
            case .sealFailed:
                return "Could not encrypt satellite payload."
            }
        }
    }

    /// Conditional check + encrypt. Call this instead of posting raw bytes to the terminal.
    static func interceptOutbound(_ plaintext: String) throws -> SealedPacket {
        let trimmed = plaintext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InterceptError.empty }
        let n = SatellitePayloadSizer.utf8ByteCount(trimmed)
        guard n <= AppConfig.Satellite.hardPayloadBytes else {
            throw InterceptError.overHardLimit(n)
        }
        guard let plain = trimmed.data(using: .utf8) else { throw InterceptError.sealFailed }
        do {
            let sealed = try AES.GCM.seal(plain, using: loadOrCreateKey())
            guard let combined = sealed.combined else { throw InterceptError.sealFailed }
            var out = Data([version])
            out.append(combined)
            return SealedPacket(ciphertext: out, plaintextByteCount: n)
        } catch {
            throw InterceptError.sealFailed
        }
    }

    static func openForTesting(_ packet: SealedPacket) throws -> String {
        guard packet.ciphertext.first == version else { throw InterceptError.sealFailed }
        let body = packet.ciphertext.dropFirst()
        let box = try AES.GCM.SealedBox(combined: Data(body))
        let plain = try AES.GCM.open(box, using: loadOrCreateKey())
        guard let text = String(data: plain, encoding: .utf8) else { throw InterceptError.sealFailed }
        return text
    }

    private static func loadOrCreateKey() -> SymmetricKey {
        if let existing = KeychainStore.load(account: keyAccount, service: keyService),
           existing.count == 32 {
            return SymmetricKey(data: existing)
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let data: Data
        if status == errSecSuccess {
            data = Data(bytes)
        } else {
            data = Data(SHA256.hash(data: Data(UUID().uuidString.utf8)))
        }
        _ = KeychainStore.save(data, account: keyAccount, service: keyService)
        return SymmetricKey(data: data)
    }
}

// MARK: - Queue / status

enum SatelliteQueueItemStatus: String, Equatable {
    case pendingTransmission = "Pending Satellite Transmission"
    case sent = "Sent via satellite terminal"
    case failed = "Satellite transmit failed"
}

struct SatelliteQueueItem: Identifiable, Equatable {
    let id: UUID
    let enqueuedAt: Date
    let plaintextByteCount: Int
    var status: SatelliteQueueItemStatus
    var detail: String
}

// MARK: - Transport (vendor SDK hook)

protocol SatelliteTerminalTransport: AnyObject {
    var isLinked: Bool { get }
    var linkLabel: String { get }
    func start()
    func stop()
    /// Deliver already-encrypted bytes to the local terminal. Completes when the
    /// terminal accepts the MO buffer (uplink itself may still take minutes).
    func transmit(_ sealed: Data, completion: @escaping (Result<Void, Error>) -> Void)
}

/// Simulated terminal: rehearses queue UX when `AppConfig.Satellite.hardwareEnabled`
/// is false (same pattern as NFC simulate mode).
final class SimulatedSatelliteTransport: SatelliteTerminalTransport {
    private(set) var isLinked = false
    var linkLabel: String {
        isLinked
            ? "Simulated terminal linked (Bluetooth)"
            : "No terminal — tap Connect to simulate Bluetooth link"
    }

    func start() {}
    func stop() { isLinked = false }

    func connectSimulated() { isLinked = true }
    func disconnectSimulated() { isLinked = false }

    func transmit(_ sealed: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isLinked else {
            completion(.failure(TransportError.notLinked))
            return
        }
        let lo = AppConfig.Satellite.simulatedTransmitSecondsMin
        let hi = AppConfig.Satellite.simulatedTransmitSecondsMax
        let delay = TimeInterval.random(in: lo...hi)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            completion(sealed.isEmpty ? .failure(TransportError.empty) : .success(()))
        }
    }

    enum TransportError: LocalizedError {
        case notLinked, empty
        var errorDescription: String? {
            switch self {
            case .notLinked: return "Satellite terminal not linked over Bluetooth."
            case .empty: return "Empty sealed payload."
            }
        }
    }
}

/// Vendor BLE adapter slot. Wire Ground Control RockBLOCK / equivalent CoreBluetooth
/// (or their Swift package once adopted) here — do **not** add CocoaPods to this repo
/// without an explicit product decision. Bracelet RF stays NFC; this radio is only
/// phone ↔ terminal.
final class SatelliteVendorTransport: NSObject, SatelliteTerminalTransport, CBCentralManagerDelegate {
    private var central: CBCentralManager?
    private(set) var isLinked = false
    private(set) var bluetoothPoweredOn = false

    var linkLabel: String {
        if !AppConfig.Satellite.hardwareEnabled {
            return "Vendor SDK parked — flip AppConfig.Satellite.hardwareEnabled after adapter wiring"
        }
        if !bluetoothPoweredOn { return "Bluetooth off — enable to reach satellite terminal" }
        return isLinked
            ? "Connected to local satellite terminal (Bluetooth)"
            : "Scanning for satellite terminal…"
    }

    func start() {
        guard AppConfig.Satellite.hardwareEnabled else { return }
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func stop() {
        central?.stopScan()
        isLinked = false
    }

    func transmit(_ sealed: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        guard AppConfig.Satellite.hardwareEnabled else {
            completion(.failure(VendorError.sdkParked))
            return
        }
        guard isLinked else {
            completion(.failure(VendorError.notLinked))
            return
        }
        // Placeholder: vendor characteristic write goes here once the SDK/GATT map
        // is chosen. Refuse rather than pretend a live Iridium MO succeeded.
        _ = sealed
        completion(.failure(VendorError.notImplemented))
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothPoweredOn = (central.state == .poweredOn)
        if bluetoothPoweredOn {
            // Vendor-specific service UUID scan plugs in here.
            central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            isLinked = false
            central.stopScan()
        }
    }

    enum VendorError: LocalizedError {
        case sdkParked, notLinked, notImplemented
        var errorDescription: String? {
            switch self {
            case .sdkParked: return "Satellite hardware SDK is parked."
            case .notLinked: return "Not connected to satellite terminal."
            case .notImplemented: return "Vendor GATT write not wired yet."
            }
        }
    }
}

// MARK: - Outbound pipeline (URLSession stand-in)

/// Single outbound choke point for satellite-bound clinician notes.
/// There is no RedMed `URLSession` API manager — this is the inject site.
@MainActor
final class SatelliteOutboundPipeline: ObservableObject {
    @Published private(set) var linkLabel = ""
    @Published private(set) var isLinked = false
    @Published private(set) var queue: [SatelliteQueueItem] = []
    @Published var lastError: String?

    private let simulated = SimulatedSatelliteTransport()
    private let vendor = SatelliteVendorTransport()

    private var transport: SatelliteTerminalTransport {
        AppConfig.Satellite.hardwareEnabled ? vendor : simulated
    }

    var usesSimulation: Bool { !AppConfig.Satellite.hardwareEnabled }

    var pendingCount: Int {
        queue.filter { $0.status == .pendingTransmission }.count
    }

    func start() {
        transport.start()
        refreshLink()
    }

    func stop() {
        transport.stop()
        refreshLink()
    }

    func toggleSimulatedLink() {
        guard usesSimulation else { return }
        if simulated.isLinked {
            simulated.disconnectSimulated()
        } else {
            simulated.connectSimulated()
        }
        refreshLink()
    }

    /// Intercept → encrypt → enqueue → transport. Never shows a spinner-only state;
    /// UI binds to `.pendingTransmission`.
    @discardableResult
    func enqueueClinicianNote(_ plaintext: String) -> Bool {
        lastError = nil
        do {
            let sealed = try SatelliteCryptoInterceptor.interceptOutbound(plaintext)
            let id = UUID()
            let item = SatelliteQueueItem(
                id: id,
                enqueuedAt: Date(),
                plaintextByteCount: sealed.plaintextByteCount,
                status: .pendingTransmission,
                detail: "Queued \(sealed.plaintextByteCount) B sealed payload"
            )
            queue.insert(item, at: 0)
            refreshLink()
            guard isLinked else {
                update(id) { $0.status = .failed; $0.detail = "Terminal not linked over Bluetooth" }
                lastError = "Connect to the satellite terminal before sending."
                return false
            }
            transport.transmit(sealed.ciphertext) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.update(id) {
                            $0.status = .sent
                            $0.detail = "Terminal accepted MO (\(sealed.plaintextByteCount) B plaintext)"
                        }
                    case .failure(let error):
                        self.update(id) {
                            $0.status = .failed
                            $0.detail = error.localizedDescription
                        }
                        self.lastError = error.localizedDescription
                    }
                }
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func update(_ id: UUID, _ body: (inout SatelliteQueueItem) -> Void) {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        var copy = queue[idx]
        body(&copy)
        queue[idx] = copy
    }

    private func refreshLink() {
        isLinked = transport.isLinked
        linkLabel = transport.linkLabel
    }
}
