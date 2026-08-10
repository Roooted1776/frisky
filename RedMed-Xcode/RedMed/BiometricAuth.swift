import LocalAuthentication

enum BiometricAuth {
    static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        #if targetEnvironment(simulator)
        // Simulator has no Face ID hardware — treat as authenticated so NFC pairing can be demoed.
        DispatchQueue.main.async { completion(true) }
        return
        #else
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
        #endif
    }
}
