import LocalAuthentication

enum BiometricPreferenceKeys {
    static let isEnabled = "security.face_id.enabled"
}

struct BiometricAuthenticationService {
    var isFaceIDAvailable: Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            return false
        }

        return context.biometryType == .faceID
    }

    func authenticate(
        reason: String,
        allowDevicePasscode: Bool = false
    ) async throws -> Bool {
        let context = LAContext()
        let policy: LAPolicy = allowDevicePasscode
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
