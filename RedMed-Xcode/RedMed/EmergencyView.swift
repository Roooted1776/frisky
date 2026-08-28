import SwiftUI
import CoreLocation

struct EmergencyView: View {
    /// Opacity keep-alive tabs never call `onDisappear` — ContentView passes
    /// whether 911 is the front tab so GPS + the seizure timer can tear down.
    var isVisible: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            PageHelpChrome()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    PrimaryButton(
                        title: "Call \(EmergencyNumber.current)",
                        systemImage: "phone.fill"
                    ) {
                        PublicEmergencyAid.dial()
                    }

                    FindHelpLocationBlock(isVisible: isVisible)
                    FindHelpSOSButton()
                    SeizureTimerStrip(isVisible: isVisible)

                    InfoCard(
                        icon: "cross.fill",
                        title: "Roadside First Response",
                        numbered: true,
                        items: [
                            "Turn on hazards. Don't move injured — unless fire or traffic danger.",
                            "Check breathing. Tilt head, lift chin. If no pulse — start CPR.",
                            "Press hard on bleeding. Don't lift to check. Add cloth on top.",
                            "Keep them warm and still. Talk to them. Note time of injury."
                        ]
                    )

                    InfoCard(
                        icon: "info.circle.fill",
                        title: "What to Tell \(EmergencyNumber.current)",
                        numbered: false,
                        items: [
                            "Your exact location — read the GPS coordinates above.",
                            "Number of people injured and visible injuries.",
                            "If anyone is unconscious or not breathing.",
                            "Stay on the line — let the dispatcher guide you."
                        ]
                    )
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.visible)
        }
        .background { RedMedPageBackground() }
    }
}
