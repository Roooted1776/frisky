import SwiftUI

/// Local history dashboard — owner only, gated by LocalAuthentication.
/// Scanners must never mount this; Help entry is owner-shell only.
struct VaultHistoryView: View {
    @ObservedObject private var store = VaultHistoryStore.shared
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var authFailed = false
    @State private var showClearConfirm = false

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Group {
            if unlocked {
                historyList
            } else {
                lockGate
            }
        }
        .background(Color.redmedBg.ignoresSafeArea())
        .navigationTitle("Local History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            HIPAAOfflineVault.prepare()
            if !unlocked && !authenticating {
                requestUnlock()
            }
        }
        .alert("Authentication Failed", isPresented: $authFailed) {
            Button("Try Again") { requestUnlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Face ID, Touch ID, or your device passcode is required to open local history.")
        }
        .confirmationDialog("Clear local history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) {
                store.clear()
                store.record(.vaultCleared)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes vault history from this iPhone. Your RedMed profile and bracelet are unchanged.")
        }
    }

    private var lockGate: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.redmedAccent)
            Text("Local History is locked")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.redmedDark)
            Text("History stays in the on-device vault (complete file protection, excluded from iCloud backup). Unlock with Face ID, Touch ID, or passcode.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button {
                requestUnlock()
            } label: {
                if authenticating {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Unlock with Face ID")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .background(Color.redmedAccent)
            .clipShape(Capsule())
            .padding(.horizontal, 40)
            .disabled(authenticating)
            Spacer()
        }
    }

    private var historyList: some View {
        List {
            Section {
                Text("Events are stored only on this iPhone under complete file protection and are excluded from iCloud backups. No profile field values are logged.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .listRowBackground(Color.redmedBg)
            }

            if store.events.isEmpty {
                Section {
                    Text("No history yet. Saving your profile or writing the bracelet adds an entry here.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.redmedMuted)
                }
            } else {
                Section("Vault activity") {
                    ForEach(store.events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: event.kind.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.redmedAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.kind.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.redmedDark)
                                if !event.detail.isEmpty {
                                    Text(event.detail)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.redmedMuted)
                                }
                                Text(Self.stampFormatter.string(from: event.createdAt))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.redmedMuted)
                            }
                        }
                        .padding(.vertical, 2)
                        .privacySensitive()
                    }
                }
            }

            if !store.events.isEmpty {
                Section {
                    Button("Clear local history", role: .destructive) {
                        showClearConfirm = true
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Lock") {
                    unlocked = false
                }
                .foregroundColor(.redmedAccent)
            }
        }
    }

    private func requestUnlock() {
        authenticating = true
        BiometricAuth.authenticate(
            reason: "Unlock local history stored in the on-device vault."
        ) { success in
            authenticating = false
            if success {
                store.reload()
                unlocked = true
                authFailed = false
            } else {
                authFailed = true
            }
        }
    }
}
