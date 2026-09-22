// Owner-only NFC bracelet setup. Ped/EMS scanner shells never mount this tab —
// see ContentView.showsNFC / scannerSafeTab.
// One page: live Save to Band + Preview + Import From Band.
// When `AppConfig.nfcHardwareEnabled` is true, Save starts a CoreNFC
// NDEF session and programs `medicalCardBaseURL#d=` from the live profile.
// Preview packs the live profile into the same tapper card helpers get.
// Import From Band reads `#d=` off the chip, Face IDs, then persist()s into
// owner Keychain (empty funnel restore). Scanners never.
// Linked after write + matching read-back, or after a successful Import.
// Parked (`false`): Copy Band Link + Share Band Link + Preview
// (never a Save button, never flips Linked; Import is hidden).
import SwiftUI

struct NFCView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    /// ContentView keep-alive never calls `onDisappear`. HTML cache may warm
    /// while this tab is front — never spawn a WKWebView here (Preview
    /// creates one when opened).
    var isVisible: Bool = true
    /// Owned by ContentView so the NFC tab tap can begin write on the same gesture.
    @ObservedObject var band: NFCBandManager
    @State private var previewSession: PreviewSession?
    /// Parked CoreNFC: packed `medicalCardBaseURL#d=` for Share Band Link only
    /// (copy/export — Share honesty, not a chip write, not Linked).
    /// Nil until pack finishes; never used to flip Linked.
    @State private var parkedBandURL: String?
    @State private var parkedPackNote: String = ""
    @State private var pendingLoadChip: NFCChipProfile?
    @State private var showLoadOverwriteConfirm = false
    @State private var showLoadAuthFailedAlert = false
    @State private var loadAuthUnavailableMessage: String?
    /// One-shot pulse on the hold diagram when the tab is front — SF Symbol only.
    @State private var holdPulse = false

    private struct PreviewSession: Identifiable {
        let id = UUID()
        let payload: String
        let embedJSON: String?
        let linked: Bool
    }

    var body: some View {
        if isScannerSession {
            Color.redmedBg.ignoresSafeArea()
        } else {
            ownerBody
        }
    }

    private var ownerBody: some View {
        VStack(spacing: 0) {
            PageHelpChrome()

            ScrollView {
                VStack(spacing: 16) {
                    if profile.showsBraceletAsLinked {
                        completeBanner
                            .padding(.top, 4)
                    } else {
                        holdDiagram
                            .padding(.top, 4)
                        howItWorksCard
                    }
                    actionsCard
                    if !profile.showsBraceletAsLinked {
                        aboutBandDisclosure
                    }
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.visible)
        }
        .fullScreenCover(item: $previewSession) { session in
            PasserbyHTMLCardView(
                payloadOrURL: session.payload,
                braceletLinked: session.linked,
                embedProfileJSON: session.embedJSON
            )
            .environment(\.isScannerSession, true)
            .presentationBackground(Color.redmedBg)
        }
        // scannedCard cover lives on ContentView so Universal Link opens work
        // even before the NFC tab is mounted.
        .alert("Bracelet", isPresented: Binding(
            get: { band.alertMessage != nil },
            set: { if !$0 { band.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { band.alertMessage = nil }
        } message: {
            Text(band.alertMessage ?? "")
        }
        .alert("Replace RedMed?", isPresented: $showLoadOverwriteConfirm) {
            Button("Cancel", role: .cancel) { pendingLoadChip = nil }
            Button("Replace") {
                if let chip = pendingLoadChip {
                    authenticateAndAdopt(chip)
                }
            }
        } message: {
            Text("This replaces the RedMed ID on this iPhone with the card on the band.")
        }
        .alert(BiometricAuth.deniedAlertTitle, isPresented: $showLoadAuthFailedAlert) {
            Button("OK", role: .cancel) { pendingLoadChip = nil }
        } message: {
            Text(BiometricAuth.deniedAlertMessage(action: "load this band into"))
        }
        .alert(BiometricAuth.unavailableAlertTitle, isPresented: Binding(
            get: { loadAuthUnavailableMessage != nil },
            set: { if !$0 { loadAuthUnavailableMessage = nil } }
        )) {
            Button("OK", role: .cancel) { pendingLoadChip = nil }
        } message: {
            Text(loadAuthUnavailableMessage ?? "")
        }
        .task(id: "\(isVisible)-\(profile.cardEpoch)") {
            // HTML string only, off the main actor. Do not create a WKWebView
            // on this tab — that was the long NFC load.
            // Session cancel on leave is ContentView (owns the band).
            guard isVisible else {
                holdPulse = false
                return
            }
            PasserbyHTMLCardView.scheduleShellWarmOnce()
            await refreshParkedBandURL()
            // Cheap SF Symbol opacity pulse — no images, no drawingGroup.
            holdPulse = false
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled, isVisible else { return }
            withAnimation(RedMedMotion.snappy) { holdPulse = true }
        }
        .onChange(of: band.isWriting) { _, writing in
            guard !writing else { return }
            linkBraceletIfVerified()
        }
        .onChange(of: band.writeVerified) { _, verified in
            guard verified, !band.isWriting else { return }
            linkBraceletIfVerified()
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedPackParkedBandURL)) { _ in
            guard isVisible else { return }
            copyParkedBandURL()
        }
    }

    /// Linked only after a matching read-back. Written-but-unverified stays Not linked.
    private func linkBraceletIfVerified() {
        guard band.writeSucceeded, band.writeVerified, AppConfig.nfcHardwareEnabled else { return }
        band.linkBracelet(on: profile, detail: "NFC write verified")
    }

    private var linkStatus: (title: String, detail: String, linked: Bool) {
        if profile.showsBraceletAsLinked {
            return (AppConfig.NFCWriteCopy.successTitle, AppConfig.NFCWriteCopy.successDetail, true)
        }
        // Incomplete identity after a real CoreNFC write. Parked builds never
        // write, so a leftover Keychain `braceletLinked` must not show
        // "Band Written" / "Finish name…" (Share honesty).
        if AppConfig.nfcHardwareEnabled, profile.braceletLinked {
            return ("Band Written", "Finish name, birth date, and blood type on RedMed", false)
        }
        return (
            "Not Linked",
            AppConfig.nfcHardwareEnabled
                ? AppConfig.NFCWriteCopy.writeHelp
                : AppConfig.NFCWriteCopy.packHelp,
            false
        )
    }

    /// Obvious done state once write + read-back linked the band.
    private var completeBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.redmedAccent)
                .accessibilityHidden(true)
            Text(AppConfig.NFCWriteCopy.successTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.redmedDark)
            Text(AppConfig.NFCWriteCopy.successDetail)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .redmedBox()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AppConfig.NFCWriteCopy.successTitle). \(AppConfig.NFCWriteCopy.successDetail)")
    }

    /// Phone → chip hold cue. SF Symbols + shapes only — no bitmap assets.
    private var holdDiagram: some View {
        VStack(spacing: 14) {
            Text(AppConfig.NFCWriteCopy.pageIntro)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.redmedDark)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                diagramGlyph(systemName: "iphone", label: "Phone")
                Image(systemName: "wave.3.right")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.redmedAccent)
                    .opacity(holdPulse ? 1 : 0.35)
                    .scaleEffect(holdPulse ? 1.05 : 0.92)
                    .accessibilityHidden(true)
                diagramBandGlyph
            }
            .padding(.vertical, 6)

            Text(AppConfig.NFCWriteCopy.holdDiagramCaption)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .multilineTextAlignment(.center)

            statusChip
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .redmedBox()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AppConfig.NFCWriteCopy.pageIntro). \(AppConfig.NFCWriteCopy.holdDiagramCaption). \(linkStatus.title).")
    }

    private var diagramBandGlyph: some View {
        VStack(spacing: 6) {
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.redmedDark.opacity(0.92))
                    .frame(width: 56, height: 28)
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedAccentLift)
            }
            Text("Band")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
        }
        .accessibilityHidden(true)
    }

    private func diagramGlyph(systemName: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 36, weight: .regular))
                .foregroundColor(.redmedDark)
                .frame(width: 52, height: 52)
                .background(Color.redmedWash.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
        }
        .accessibilityHidden(true)
    }

    private var statusChip: some View {
        let status = linkStatus
        return HStack(spacing: 8) {
            Circle()
                .fill(status.linked ? Color.redmedAccent : Color.redmedMuted.opacity(0.45))
                .frame(width: 8, height: 8)
            Text(status.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.redmedDark)
            Text("·")
                .foregroundColor(.redmedMuted)
            Text(status.detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.redmedMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.redmedBg)
        .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous)
                .strokeBorder(Color.redmedDivider, lineWidth: 1)
        )
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: AppConfig.NFCWriteCopy.howItWorksLabel)
            ForEach(Array(AppConfig.NFCWriteCopy.tutorialSteps.enumerated()), id: \.offset) { index, step in
                tutorialStepRow(icon: step.icon, title: step.title, detail: step.detail)
                if index < AppConfig.NFCWriteCopy.tutorialSteps.count - 1 {
                    thinRule
                }
            }
        }
        .padding(16)
        .redmedBox()
    }

    private func tutorialStepRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.redmedAccent)
                .frame(width: 32, height: 32)
                .background(Color.redmedWash.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.redmedDark)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: AppConfig.NFCWriteCopy.doThisNowLabel)

            PrimaryButton(
                title: primaryActionTitle,
                subtitle: primaryActionSubtitle,
                systemImage: band.isWriting ? nil : "wave.3.right",
                busy: band.isWriting,
                disabled: !profile.hasSensitiveProfileData || band.isBusy,
                flatten: false
            ) {
                handlePrimaryAction()
            }

            if AppConfig.nfcHardwareEnabled {
                tipRow(AppConfig.NFCWriteCopy.holdTopTip)
                previewButton
                OutlineButton(
                    title: band.isReading
                        ? AppConfig.NFCWriteCopy.loadBusyTitle
                        : AppConfig.NFCWriteCopy.loadTitle,
                    systemImage: band.isReading ? nil : "arrow.down.to.line",
                    busy: band.isReading,
                    disabled: band.isBusy
                ) {
                    startLoadFromBand()
                }
                .accessibilityLabel(AppConfig.NFCWriteCopy.loadTitle)
                .accessibilityHint("Reads the bracelet into this iPhone. Face ID required. Replaces the RedMed ID here.")
            } else {
                parkedShareControl
                previewButton
                Text(AppConfig.NFCWriteCopy.parkedHonestyShort)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !profile.hasSensitiveProfileData {
                Text(
                    AppConfig.nfcHardwareEnabled
                        ? AppConfig.NFCWriteCopy.fillBeforeWrite
                        : AppConfig.NFCWriteCopy.fillBeforePack
                )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
            }

            writeOutcomeBlock

            if !parkedPackNote.isEmpty {
                Text(parkedPackNote)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .redmedBox()
    }

    /// Deep RF / chip facts stay available but off the first read.
    private var aboutBandDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 0) {
                factRow(icon: "cpu", text: AppConfig.BraceletRF.chipSpecSummary)
                thinRule
                factRow(icon: "hand.point.up.left.fill", text: AppConfig.BraceletRF.tapDistanceSummary)
                thinRule
                factRow(icon: "iphone.radiowaves.left.and.right", text: AppConfig.BraceletRF.powerOnTapSummary)
                thinRule
                factRow(icon: "lock.open.fill", text: AppConfig.BraceletRF.backgroundTagReadingSummary)
                thinRule
                factRow(icon: "person.2.fill", text: AppConfig.BraceletRF.passerbyTapSummary)
                thinRule
                factRow(icon: "internaldrive", text: AppConfig.OwnerBandURI.storesIndependenceSummary)
                if !AppConfig.nfcHardwareEnabled {
                    thinRule
                    factRow(icon: "info.circle", text: AppConfig.BraceletRF.hardwareParkedSummary)
                }
            }
            .padding(.top, 8)
        } label: {
            Text(AppConfig.NFCWriteCopy.aboutBandLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.redmedMuted)
        }
        .tint(.redmedAccent)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .redmedBox()
    }

    private var previewButton: some View {
        OutlineButton(
            title: "Preview",
            systemImage: "eye",
            disabled: !profile.hasSensitiveProfileData || band.isBusy || previewSession != nil
        ) {
            openFirstResponderPreview()
        }
    }

    @ViewBuilder
    private var writeOutcomeBlock: some View {
        if showsWriteFailCopy {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppConfig.NFCWriteCopy.failTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.redmedAccent)
                Text(AppConfig.NFCWriteCopy.failDetail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        } else if showsWriteSuccessCopy {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppConfig.NFCWriteCopy.successTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.redmedDark)
                Text(AppConfig.NFCWriteCopy.successDetail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        } else if !band.statusMessage.isEmpty, !hidesWriteStatus {
            Text(band.statusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(statusIsError ? .redmedAccent : .redmedMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var parkedShareControl: some View {
        if let parkedBandURL {
            ShareLink(item: parkedBandURL) {
                shareBandURLLabel
            }
            .disabled(band.isBusy)
            .opacity(band.isBusy ? 0.72 : 1)
            .accessibilityLabel(AppConfig.NFCWriteCopy.shareTitle)
            .accessibilityHint("Shares the same link Save to Band will put on the chip when Tag Reading is restored. Does not write the band and does not mark Linked.")
        } else {
            shareBandURLLabel
                .opacity(RedMedChrome.disabledOpacity)
                .accessibilityLabel(AppConfig.NFCWriteCopy.shareTitle)
                .accessibilityHint("Fill RedMed first to share the band link.")
        }
    }

    private var shareBandURLLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 17, weight: .semibold))
            Text(AppConfig.NFCWriteCopy.shareTitle)
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(.redmedAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color.redmedBg)
        .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous)
                .strokeBorder(Color.redmedAccent.opacity(0.45), lineWidth: 1.5)
        )
    }

    private func refreshParkedBandURL() async {
        guard !AppConfig.nfcHardwareEnabled, profile.hasSensitiveProfileData else {
            parkedBandURL = nil
            parkedPackNote = ""
            return
        }
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        let packed = await Task.detached(priority: .userInitiated) {
            ProfileNFCCodec.buildURLString(chip: chip)
        }.value
        guard let packed, AppConfig.OwnerBandURI.isValidWriteURL(packed) else {
            parkedBandURL = nil
            parkedPackNote = "Couldn't pack a RedMed #d= URL."
            return
        }
        if packed.utf8.count > 850 {
            parkedBandURL = nil
            parkedPackNote = "\(packed.utf8.count) bytes — too large for NXP NTAG216. Shorten RedMed."
            return
        }
        parkedPackNote = ""
        parkedBandURL = packed
    }

    private func openFirstResponderPreview() {
        guard !isScannerSession, profile.hasSensitiveProfileData, previewSession == nil else { return }
        let chip = ProfileNFCCodec.chipProfile(from: profile)
        let linked = profile.showsBraceletAsLinked
        Task { @MainActor in
            let packed = await Task.detached(priority: .userInitiated) {
                (
                    ProfileNFCCodec.previewPayload(from: chip)
                        ?? ProfileNFCCodec.placeholderPreviewPayload,
                    ProfileNFCCodec.embedProfileJSON(from: chip)
                )
            }.value
            guard previewSession == nil else { return }
            previewSession = PreviewSession(
                payload: packed.0,
                embedJSON: packed.1,
                linked: linked
            )
        }
    }

    private func startLoadFromBand() {
        guard !isScannerSession, AppConfig.nfcHardwareEnabled, !band.isBusy else { return }
        band.readBandForLoad(isScannerSession: isScannerSession) { chip in
            Task { @MainActor in
                handleLoadedChip(chip)
            }
        }
    }

    private func handleLoadedChip(_ chip: NFCChipProfile) {
        guard chip.hasAnyProfileData else {
            pendingLoadChip = nil
            band.alertMessage = "This band has no RedMed ID."
            return
        }
        if profile.matchesBand(chip) {
            pendingLoadChip = nil
            if profile.showsBraceletAsLinked {
                band.statusMessage = "This band matches RedMed."
                return
            }
            authenticateAndLinkMatchingBand()
            return
        }
        pendingLoadChip = chip
        if profile.hasSensitiveProfileData {
            showLoadOverwriteConfirm = true
        } else {
            authenticateAndAdopt(chip)
        }
    }

    private func authenticateAndLinkMatchingBand() {
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to mark this band as linked.",
            force: true
        ) { outcome in
            Task { @MainActor in
                switch outcome {
                case .success:
                    if profile.setBraceletPaired(true) {
                        band.statusMessage = "This band matches RedMed. Linked."
                    } else {
                        band.alertMessage = "Couldn't save the linked status. Try again."
                    }
                case .notVerified:
                    showLoadAuthFailedAlert = true
                case .unavailable(let reason):
                    loadAuthUnavailableMessage = reason.message
                default:
                    break
                }
            }
        }
    }

    private func authenticateAndAdopt(_ chip: NFCChipProfile) {
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode to load this band into RedMed.",
            force: true
        ) { outcome in
            Task { @MainActor in
                switch outcome {
                case .success:
                    if profile.adoptBandSnapshot(chip) {
                        pendingLoadChip = nil
                        band.statusMessage = "Loaded into RedMed."
                    } else {
                        pendingLoadChip = nil
                        band.alertMessage = "Couldn't save the band into RedMed. Try again."
                    }
                case .notVerified:
                    showLoadAuthFailedAlert = true
                case .unavailable(let reason):
                    loadAuthUnavailableMessage = reason.message
                default:
                    pendingLoadChip = nil
                }
            }
        }
    }

    private var primaryActionTitle: String {
        if band.isWriting {
            return AppConfig.nfcHardwareEnabled
                ? AppConfig.NFCWriteCopy.writeBusyTitle
                : AppConfig.NFCWriteCopy.packBusyTitle
        }
        return AppConfig.nfcHardwareEnabled
            ? AppConfig.NFCWriteCopy.writeTitle
            : AppConfig.NFCWriteCopy.packTitle
    }

    private var primaryActionSubtitle: String? {
        guard !band.isWriting else { return nil }
        return AppConfig.nfcHardwareEnabled
            ? AppConfig.NFCWriteCopy.writeHelp
            : AppConfig.NFCWriteCopy.packHelp
    }

    private func handlePrimaryAction() {
        if AppConfig.nfcHardwareEnabled {
            band.writeBand(from: profile, isScannerSession: isScannerSession)
        } else {
            copyParkedBandURL()
        }
    }

    private func copyParkedBandURL() {
        guard !isScannerSession, !AppConfig.nfcHardwareEnabled else { return }
        guard profile.hasSensitiveProfileData else { return }
        if let url = parkedBandURL {
            SecurePasteboard.copyEphemeral(url, lifetimeSeconds: 120)
            parkedPackNote = ""
            band.statusMessage = AppConfig.NFCWriteCopy.packCopiedStatus
            return
        }
        Task { @MainActor in
            await refreshParkedBandURL()
            guard let url = parkedBandURL else { return }
            SecurePasteboard.copyEphemeral(url, lifetimeSeconds: 120)
            band.statusMessage = AppConfig.NFCWriteCopy.packCopiedStatus
        }
    }

    private var showsWriteFailCopy: Bool {
        guard AppConfig.nfcHardwareEnabled, !band.isWriting, !band.isReading else { return false }
        let msg = band.statusMessage
        return msg == AppConfig.NFCWriteCopy.failTitle
            || msg == AppConfig.NFCWriteCopy.failDetail
    }

    private var showsWriteSuccessCopy: Bool {
        guard AppConfig.nfcHardwareEnabled, !band.isWriting else { return false }
        if profile.showsBraceletAsLinked { return false }
        return band.writeSucceeded && band.writeVerified
            || band.statusMessage == AppConfig.NFCWriteCopy.successTitle
            || band.statusMessage == AppConfig.NFCWriteCopy.successDetail
    }

    private var hidesWriteStatus: Bool {
        let msg = band.statusMessage
        return msg == AppConfig.NFCWriteCopy.successTitle
            || msg == AppConfig.NFCWriteCopy.successDetail
            || msg == AppConfig.NFCWriteCopy.failTitle
            || msg == AppConfig.NFCWriteCopy.failDetail
            || (profile.showsBraceletAsLinked && band.writeSucceeded)
    }

    private var statusIsError: Bool {
        let msg = band.statusMessage
        if msg == "Cancelled." { return false }
        if msg == AppConfig.NFCWriteCopy.failTitle || msg == AppConfig.NFCWriteCopy.failDetail {
            return true
        }
        if msg.contains("Couldn't") || msg.contains("failed") || msg.contains("Failed") {
            return true
        }
        if msg.hasPrefix("Loaded") || msg.hasPrefix("This band matches")
            || msg == AppConfig.NFCWriteCopy.packCopiedStatus {
            return false
        }
        return !band.writeSucceeded && !msg.isEmpty && !band.isWriting && !band.isReading
            && msg != "Hold your iPhone near the NFC tag."
    }

    private var thinRule: some View {
        Divider().overlay(Color.redmedDivider)
    }

    @ViewBuilder
    private func factRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.redmedAccent)
                .frame(width: 28, alignment: .center)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedDark)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.redmedAccent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
                .lineSpacing(2)
        }
    }
}
