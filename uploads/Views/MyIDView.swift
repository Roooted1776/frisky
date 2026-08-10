import SwiftUI

/// Owner My ID tab — read-only summary; Edit sheet prompts Face ID only when
/// changing saved profile data (`EditProfileView`).
struct MyIDView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var link: BraceletLinkStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingEditSheet = false
    @State private var showingBraceletSetup = false
    @State private var showingHowItWorks = false
    @AppStorage("redMedUseConsent") private var useConsentAccepted = false
    @State private var showingConsent = false

    var body: some View {
        NavigationStack {
            ProfileSummaryView(profile: store.profile, link: link)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingBraceletSetup = true
                        } label: {
                            BraceletToolbarButton(link: link)
                        }
                        .accessibilityLabel("Bracelet setup")
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingHowItWorks = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .foregroundStyle(AppTheme.muted)
                        .accessibilityLabel("How it works")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if useConsentAccepted {
                                showingEditSheet = true
                            } else {
                                showingConsent = true
                            }
                        } label: {
                            Text("Edit").bold()
                        }
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityLabel("Edit")
                    }
                }
        }
        .tint(AppTheme.accent)
        .onChange(of: scenePhase) { phase in
            if phase == .background { showingEditSheet = false }
        }
        .sheet(isPresented: $showingBraceletSetup) {
            BraceletSetupView()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProfileView(embedded: false)
        }
        .sheet(isPresented: $showingHowItWorks) {
            HowItWorksView()
                .withLayoutMetrics()
        }
        .fullScreenCover(isPresented: $showingConsent) {
            UseConsentView {
                useConsentAccepted = true
                showingConsent = false
                showingEditSheet = true
            }
            .withLayoutMetrics()
        }
    }
}

#Preview {
    MyIDView()
        .environmentObject(ProfileStore())
        .environmentObject(BraceletLinkStore())
}
