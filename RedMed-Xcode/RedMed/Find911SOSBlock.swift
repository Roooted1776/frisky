import CoreLocation
import CoreMotion
import MessageUI
import Network
import SwiftUI
import UIKit

// MARK: - Find 911 SOS (sits directly under Live GPS)

/// Self-contained SOS block for the Xcode Find 911 tab.
/// Device-direct: optional third-party HTTPS + telprompt:911 + carrier SMS. No RedMed server.
struct Find911SOSBlock: View {
    @EnvironmentObject private var profile: ProfileData
    @ObservedObject var locationManager: LocationManager

    @StateObject private var network = OfflinePathMonitor()
    @StateObject private var sos = Find911SOSController()
    @StateObject private var motion = Find911MotionAssist()
    @StateObject private var outbound = Find911Outbound()

    @State private var seizureRunning = false
    @State private var seizureElapsed: TimeInterval = 0
    @State private var seizureTask: Task<Void, Never>?
    @State private var motionForSeizure = false

    private static let seizureAutoSeconds: TimeInterval = 5 * 60

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EMERGENCY SOS")
                .font(.system(size: 9, weight: .bold))
                .kerning(1.1)
                .foregroundColor(.redmedAccent)

            PrimaryButton(title: network.isOffline ? "Emergency SOS · Satellite path" : "Emergency SOS") {
                sos.startCountdown(isOffline: network.isOffline)
            }
            .disabled(sos.isCountingDown)

            Text(network.isOffline
                 ? "No cell path. Countdown opens Satellite SOS steps — RedMed cannot start Apple Satellite SOS."
                 : "Countdown → optional third-party alert API → dial 911 → Messages SMS to contacts. No RedMed server.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: Binding(
                get: { motion.isEnabled },
                set: { motion.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Motion assist")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedDark)
                    Text("Hard sustained jolt starts the same countdown while this screen is open. Off by default.")
                        .font(.system(size: 10))
                        .foregroundColor(.redmedMuted)
                }
            }
            .tint(.redmedAccent)

            Divider().background(Color.redmedDivider)

            Text("Seizure timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.redmedDark)
            Text("Time it. Don’t restrain. Don’t put anything in the mouth. Call if first seizure, over 5 minutes, no recovery, injury, or in water.")
                .font(.system(size: 10))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)

            Text(formatElapsed(seizureElapsed))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(seizureElapsed >= Self.seizureAutoSeconds ? .redmedAccent : .redmedDark)
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                SecondaryButton(seizureRunning ? "Stop timer" : "Start seizure timer") {
                    if seizureRunning { stopSeizure(reset: false) } else { startSeizure() }
                }
                PrimaryButton(title: "Call now") {
                    sos.fireNow(isOffline: network.isOffline)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
        .fullScreenCover(isPresented: Binding(
            get: { sos.isCountingDown },
            set: { if !$0 { sos.cancel() } }
        )) {
            Find911SOSCountdownOverlay(sos: sos, isOffline: network.isOffline)
        }
        .fullScreenCover(isPresented: Binding(
            get: { sos.showsSatelliteCoach },
            set: { if !$0 { sos.dismissSatelliteCoach() } }
        )) {
            Find911SatelliteCoach(
                location: locationManager.location,
                onDismiss: { sos.dismissSatelliteCoach() }
            )
        }
        .sheet(isPresented: $outbound.showSMSComposer) {
            Find911SMSComposer(
                recipients: outbound.smsRecipients,
                body: outbound.smsBody,
                onFinish: { outbound.showSMSComposer = false }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            network.start()
            outbound.locationManager = locationManager
            let profileRef = profile
            outbound.profileProvider = { [weak profileRef] in profileRef }
            let networkRef = network
            sos.isOfflineCheck = { [weak networkRef] in networkRef?.isOffline ?? false }
            let outboundRef = outbound
            sos.onOnlineFire = { [weak outboundRef] in outboundRef?.fireOnline() }
            if motion.isEnabled { motion.start() }
        }
        .onDisappear {
            network.stop()
            motion.stop()
            stopSeizure(reset: false)
            if sos.isCountingDown { sos.cancel() }
        }
        .onChange(of: motion.isEnabled) { _, enabled in
            if enabled { motion.start() } else { motion.stop() }
        }
        .onChange(of: motion.didTrigger) { _, triggered in
            guard triggered else { return }
            motion.consumeTrigger()
            guard !sos.isCountingDown, !sos.showsSatelliteCoach else { return }
            sos.startCountdown(isOffline: network.isOffline)
        }
    }

    private func startSeizure() {
        stopSeizure(reset: true)
        seizureRunning = true
        if !motion.isEnabled {
            motion.setEnabled(true)
            motionForSeizure = true
        }
        let started = Date()
        seizureTask = Task { @MainActor in
            while !Task.isCancelled {
                seizureElapsed = Date().timeIntervalSince(started)
                if seizureElapsed >= Self.seizureAutoSeconds {
                    stopSeizure(reset: false)
                    sos.fireNow(isOffline: network.isOffline)
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func stopSeizure(reset: Bool) {
        seizureTask?.cancel()
        seizureTask = nil
        seizureRunning = false
        if reset { seizureElapsed = 0 }
        if motionForSeizure {
            motion.setEnabled(false)
            motionForSeizure = false
        }
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Controllers (Xcode target — local, no RedMed server)

@MainActor
final class Find911SOSController: ObservableObject {
    enum Phase { case idle, countdown, satelliteCoach }
    static let countdownSeconds = 8

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var secondsRemaining = countdownSeconds

    private var task: Task<Void, Never>?
    var isOfflineCheck: () -> Bool = { false }
    var onOnlineFire: () -> Void = {
        if let url = URL(string: "telprompt:911") { UIApplication.shared.open(url) }
    }

    var isCountingDown: Bool { phase == .countdown }
    var showsSatelliteCoach: Bool { phase == .satelliteCoach }

    func startCountdown(isOffline _: Bool) {
        task?.cancel()
        phase = .countdown
        secondsRemaining = Self.countdownSeconds
        task = Task { [weak self] in
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
        task?.cancel()
        task = nil
        phase = .idle
        secondsRemaining = Self.countdownSeconds
    }

    func dismissSatelliteCoach() { phase = .idle }

    func fireNow(isOffline: Bool) {
        task?.cancel()
        task = nil
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
}

@MainActor
final class Find911MotionAssist: ObservableObject {
    @Published var isEnabled = false
    @Published private(set) var didTrigger = false

    private let manager = CMMotionManager()
    private var elevatedSince: Date?
    private var lastTrigger: Date?
    private var running = false

    private static let peakG = 2.8
    private static let sustain: TimeInterval = 1.2
    private static let cooldown: TimeInterval = 30

    func setEnabled(_ on: Bool) {
        isEnabled = on
        if on { start() } else { stop() }
    }

    func start() {
        guard isEnabled, !running, manager.isDeviceMotionAvailable else { return }
        running = true
        elevatedSince = nil
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion, self.isEnabled else { return }
            let a = motion.userAcceleration
            let mag = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            if let last = self.lastTrigger, Date().timeIntervalSince(last) < Self.cooldown { return }
            if mag >= Self.peakG {
                if self.elevatedSince == nil {
                    self.elevatedSince = Date()
                } else if let since = self.elevatedSince,
                          Date().timeIntervalSince(since) >= Self.sustain {
                    self.elevatedSince = nil
                    self.lastTrigger = Date()
                    self.didTrigger = true
                }
            } else {
                self.elevatedSince = nil
            }
        }
    }

    func stop() {
        guard running else { return }
        running = false
        manager.stopDeviceMotionUpdates()
        elevatedSince = nil
    }

    func consumeTrigger() { didTrigger = false }
}

@MainActor
final class Find911Outbound: ObservableObject {
    @Published var showSMSComposer = false
    @Published var smsBody = ""
    @Published var smsRecipients: [String] = []

    weak var locationManager: LocationManager?
    var profileProvider: () -> ProfileData? = { nil }

    /// Empty = no HTTPS. Set at build time for RapidSOS / Noonlight / webhook.
    static let thirdPartyURL = ""
    static let thirdPartyToken = ""

    func fireOnline() {
        let profile = profileProvider()
        let loc = locationManager?.location
        let phones: [String] = (profile?.contacts ?? []).compactMap { contact in
            let digits = contact.detail.filter { $0.isNumber || $0 == "+" }
            return digits.isEmpty ? nil : digits
        }

        Task {
            await Self.postThirdParty(profile: profile, location: loc)
        }

        if let url = URL(string: "telprompt:911") {
            UIApplication.shared.open(url)
        }

        guard !phones.isEmpty else { return }
        smsRecipients = phones
        smsBody = Self.smsBody(profile: profile, location: loc)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.showSMSComposer = true
        }
    }

    private static func smsBody(profile: ProfileData?, location: CLLocation?) -> String {
        var lines = ["EMERGENCY LOCATION — RedMed"]
        if let location {
            let c = location.coordinate
            lines.append(String(format: "Decimal: %.6f, %.6f", c.latitude, c.longitude))
            lines.append(String(format: "Accuracy: ±%.0f m", location.horizontalAccuracy))
            lines.append("Apple Maps: https://maps.apple.com/?ll=\(c.latitude),\(c.longitude)")
        } else {
            lines.append("Location: Tell dispatcher your location")
        }
        if let profile {
            lines.append("")
            lines.append("Medical:")
            if !profile.name.isEmpty { lines.append("Name: \(profile.name)") }
            if !profile.bloodType.isEmpty { lines.append("Blood: \(profile.bloodType)") }
            if !profile.allergies.isEmpty { lines.append("Allergies: \(profile.allergies.joined(separator: ", "))") }
            if !profile.conditions.isEmpty { lines.append("Conditions: \(profile.conditions.joined(separator: ", "))") }
            if !profile.medications.isEmpty { lines.append("Meds: \(profile.medications.joined(separator: ", "))") }
        }
        return lines.joined(separator: "\n")
    }

    private static func postThirdParty(profile: ProfileData?, location: CLLocation?) async {
        let raw = thirdPartyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let url = URL(string: raw) else { return }
        var body: [String: Any] = [
            "source": "RedMed",
            "event": "find911_sos"
        ]
        if let location {
            body["latitude"] = location.coordinate.latitude
            body["longitude"] = location.coordinate.longitude
            body["accuracyMeters"] = location.horizontalAccuracy
        }
        if let profile {
            body["name"] = profile.name
            body["bloodType"] = profile.bloodType
            body["allergies"] = profile.allergies
            body["conditions"] = profile.conditions
            body["medications"] = profile.medications
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8
        req.httpBody = data
        let token = thirdPartyToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        _ = try? await URLSession.shared.data(for: req)
    }
}

final class OfflinePathMonitor: ObservableObject {
    @Published private(set) var isOffline = false
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "local.redmed.offline")

    /// Start after first paint — constructing NWPathMonitor in `init` competes with tab chrome.
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

    deinit { monitor?.cancel() }
}

struct Find911SOSCountdownOverlay: View {
    @ObservedObject var sos: Find911SOSController
    var isOffline: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(isOffline ? "Satellite SOS steps in" : "Calling 911 in")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Text("\(sos.secondsRemaining)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("Tap Cancel if this was a false alarm.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                SecondaryButton("Cancel") { sos.cancel() }
                    .frame(maxWidth: 220)
            }
            .padding(24)
        }
        .allowsHitTesting(true)
    }
}

struct Find911SatelliteCoach: View {
    let location: CLLocation?
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("No usable cell path. RedMed cannot start Emergency SOS via satellite — use the iPhone hardware steps below.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)
                    Text("1. Hold Side + Volume until Emergency SOS appears.\n2. Drag Emergency SOS, or keep holding.\n3. iPhone 14+ can use satellite with a clear sky view.\n4. Read GPS below to the dispatcher if connected.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.redmedDark)
                    if let loc = location {
                        Text(String(format: "%.6f, %.6f", loc.coordinate.latitude, loc.coordinate.longitude))
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundColor(.redmedDark)
                    }
                    Link("Apple guide: Emergency SOS via satellite",
                         destination: URL(string: "https://support.apple.com/en-us/102669")!)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                    SecondaryButton("Try Phone · dial 911 anyway") {
                        if let url = URL(string: "telprompt:911") { UIApplication.shared.open(url) }
                    }
                }
                .padding(16)
            }
            .background(Color.redmedBg)
            .navigationTitle("Satellite SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }
}

struct Find911SMSComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMessageComposeViewController.canSendText() else {
            if let first = recipients.first {
                let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "sms:\(first)&body=\(encoded)") {
                    UIApplication.shared.open(url)
                }
            }
            let host = UIViewController()
            DispatchQueue.main.async { onFinish() }
            return host
        }
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true) { [onFinish] in onFinish() }
        }
    }
}
