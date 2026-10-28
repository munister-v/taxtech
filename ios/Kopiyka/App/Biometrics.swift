import LocalAuthentication

/// Face ID / Touch ID замість PIN. Біометрія лише відмикає банк на телефоні: токен і так у Keychain.
enum Biometrics {
    enum Kind { case none, faceID, touchID, opticID }

    static var kind: Kind {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return .none }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    static var title: String {
        switch kind {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .none: "Біометрія"
        }
    }

    static var symbol: String {
        switch kind {
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "faceid"
        }
    }

    /// true - власника впізнано; скасування чи збій - false, тоді лишається PIN.
    static func unlock(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Ввести PIN"
        return (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) ?? false
    }
}
