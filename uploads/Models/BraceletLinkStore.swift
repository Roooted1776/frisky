import Foundation

/// Tracks the owner's linked bracelet (device name + chip URL) and a short
/// "nearby" pulse after a successful NFC read/write — iOS has no silent
/// background tag polling like Web NFC scan on Android Chrome.
@MainActor
final class BraceletLinkStore: ObservableObject {
    @Published private(set) var isNearby = false

    @Published var deviceName: String {
        didSet { UserDefaults.standard.set(deviceName, forKey: Keys.name) }
    }

    /// Full chip URL embeds `#d=` medical payload — Keychain, not UserDefaults.
    @Published var deviceURL: String {
        didSet { Self.persistURL(deviceURL) }
    }

    /// One-time pass on the edit-auth gate, active for exactly the first
    /// foreground session that follows pairing — never the pairing session
    /// itself. Consulted directly by `EditProfileView.requiresEditAuth`.
    @Published var pendingPostPairingGrace: Bool {
        didSet { UserDefaults.standard.set(pendingPostPairingGrace, forKey: Keys.pendingGrace) }
    }

    /// Pairing just happened; waiting for the app to background at least once
    /// and come back before the grace above goes live. Persisted so the
    /// pairing session itself never sees the grace, even if it backgrounds
    /// and returns before we've observed a *later* independent foreground.
    @Published private var postPairingGraceArmed: Bool {
        didSet { UserDefaults.standard.set(postPairingGraceArmed, forKey: Keys.graceArmed) }
    }

    /// True once the app has backgrounded at least once since arming —
    /// the signal that the *next* activation is a genuinely new session.
    @Published private var postPairingGraceBackgrounded: Bool {
        didSet { UserDefaults.standard.set(postPairingGraceBackgrounded, forKey: Keys.graceBackgrounded) }
    }

    enum Keys {
        static let name = "redMedBraceletDeviceName"
        static let url = "redMedBraceletDeviceURL"
        static let legacyPaired = "redMedBraceletPaired"
        static let urlAccount = "braceletDeviceURL"
        static let pendingGrace = "redMedPostPairingEditGrace"
        static let graceArmed = "redMedPostPairingEditGraceArmed"
        static let graceBackgrounded = "redMedPostPairingEditGraceBackgrounded"
    }

    private var nearbyTimer: Timer?

    init() {
        deviceName = UserDefaults.standard.string(forKey: Keys.name) ?? ""
        deviceURL = Self.loadURL()
        pendingPostPairingGrace = UserDefaults.standard.bool(forKey: Keys.pendingGrace)
        postPairingGraceArmed = UserDefaults.standard.bool(forKey: Keys.graceArmed)
        postPairingGraceBackgrounded = UserDefaults.standard.bool(forKey: Keys.graceBackgrounded)
        if deviceURL.isEmpty, UserDefaults.standard.bool(forKey: Keys.legacyPaired) {
            deviceName = deviceName.isEmpty ? "My bracelet" : deviceName
        }
    }

    /// Shared with `RedMedApp` deep-link ignore-own-band check.
    static func loadURL() -> String {
        if let data = KeychainStore.load(account: Keys.urlAccount),
           let url = String(data: data, encoding: .utf8),
           !url.isEmpty {
            return url
        }
        let legacy = UserDefaults.standard.string(forKey: Keys.url) ?? ""
        if !legacy.isEmpty {
            persistURL(legacy)
            UserDefaults.standard.removeObject(forKey: Keys.url)
        }
        return legacy
    }

    private static func persistURL(_ url: String) {
        if url.isEmpty {
            KeychainStore.delete(account: Keys.urlAccount)
        } else if let data = url.data(using: .utf8) {
            KeychainStore.save(data, account: Keys.urlAccount)
        }
        UserDefaults.standard.removeObject(forKey: Keys.url)
    }

    var isLinked: Bool { !deviceURL.isEmpty }

    var headerTitle: String {
        isLinked && !deviceName.isEmpty ? deviceName : "RedMed"
    }

    func link(name: String, url: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        deviceName = trimmed.isEmpty ? "My bracelet" : trimmed
        deviceURL = url
        UserDefaults.standard.set(true, forKey: Keys.legacyPaired)
        pendingPostPairingGrace = false
        postPairingGraceArmed = true
        postPairingGraceBackgrounded = false
        markNearby()
    }

    /// Call on every app-wide transition to `.background`. Only marks that a
    /// session boundary has passed since arming — does NOT touch an active
    /// grace. Consumption of an active grace is `EditProfileView`'s job (see
    /// `consumePostPairingGrace()`), kept local to the view that owns the
    /// lock state so it isn't racing another view's scenePhase observer for
    /// the same transition.
    func noteAppDidBackground() {
        if postPairingGraceArmed { postPairingGraceBackgrounded = true }
    }

    /// Consumes an active grace. Call from the edit screen's own
    /// backgrounding handler so lock re-engagement isn't dependent on
    /// cross-view `onChange` ordering for the same scenePhase transition.
    func consumePostPairingGrace() {
        pendingPostPairingGrace = false
    }

    /// Call on every app-wide transition to `.active` (including cold
    /// launch). Promotes an armed grace to active only if we've seen at
    /// least one backgrounding since it was armed — i.e. this activation is
    /// not the same session pairing happened in.
    func promotePostPairingGraceIfEligible() {
        guard postPairingGraceArmed, postPairingGraceBackgrounded else { return }
        pendingPostPairingGrace = true
        postPairingGraceArmed = false
        postPairingGraceBackgrounded = false
    }

    func updateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLinked else { return }
        deviceName = trimmed.isEmpty ? "My bracelet" : trimmed
    }

    func clear() {
        deviceName = ""
        deviceURL = ""
        isNearby = false
        nearbyTimer?.invalidate()
        nearbyTimer = nil
        pendingPostPairingGrace = false
        postPairingGraceArmed = false
        postPairingGraceBackgrounded = false
        UserDefaults.standard.removeObject(forKey: Keys.legacyPaired)
    }

    func markNearby() {
        isNearby = true
        nearbyTimer?.invalidate()
        nearbyTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.isNearby = false }
        }
    }

    func matches(url: String) -> Bool {
        !deviceURL.isEmpty && deviceURL == url
    }
}
