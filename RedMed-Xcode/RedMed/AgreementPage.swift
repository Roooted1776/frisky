import SwiftUI

/// Privacy / Terms / Security — static user-page cream (`Color.redmedBg`).
/// Help and lock present this as the agreement page. Help.html stays the
/// HTML source; this Swift page is the durable shell when Help / lock get
/// rewritten.
struct AgreementPage: View {
    var start: HelpDocument.Policy = .terms
    @Environment(\.dismiss) private var dismiss
    @State private var page: HelpDocument.Policy

    init(start: HelpDocument.Policy = .terms) {
        self.start = start
        _page = State(initialValue: start)
    }

    var body: some View {
        VStack(spacing: 0) {
            OwnerModalChrome(
                title: page.title,
                leadingTitle: "Done",
                leadingAction: { dismiss() }
            )

            TabView(selection: $page) {
                ForEach(HelpDocument.Policy.allCases) { policy in
                    LocalWebView(
                        filename: HelpDocument.bundledFile,
                        fragment: policy.fragment
                    )
                    .tag(policy)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .background(Color.redmedBg.ignoresSafeArea())
        .presentationBackground(Color.redmedBg)
        .toolbar(.hidden, for: .navigationBar)
    }
}
