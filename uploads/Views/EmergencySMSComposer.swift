import MessageUI
import SwiftUI
import UIKit

/// Carrier SMS via Apple Messages — third-party delivery, no RedMed server.
/// User must tap Send. Falls back to `sms:` URL if the composer cannot send.
struct EmergencySMSComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMessageComposeViewController.canSendText() else {
            // Simulator / iPad without Messages — open sms: for first recipient.
            if let first = recipients.first {
                let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let digits = first.filter { $0.isNumber || $0 == "+" }
                if let url = URL(string: "sms:\(digits)&body=\(encoded)") {
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
