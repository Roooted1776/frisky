import LocalAuthentication
import UIKit

enum BiometricAuth {
    /// Prompts for Face ID or device passcode. On Simulator, uses LA when enrolled;
    /// otherwise shows a confirm dialog so edit flows still demonstrate the gate.
    static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
            return
        }

        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            presentSimulatorPrompt(reason: reason, completion: completion)
        }
        #else
        DispatchQueue.main.async { completion(false) }
        #endif
    }

    #if targetEnvironment(simulator)
    private static func presentSimulatorPrompt(reason: String, completion: @escaping (Bool) -> Void) {
        guard let top = topViewController() else {
            completion(true)
            return
        }
        let alert = UIAlertController(
            title: "Face ID or Passcode",
            message: reason,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
            completion(false)
        })
        alert.addAction(UIAlertAction(title: "Authenticate", style: .default) { _ in
            completion(true)
        })
        top.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
    #endif
}
