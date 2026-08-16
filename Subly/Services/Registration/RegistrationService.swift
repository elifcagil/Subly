import Foundation

struct RegistrationResult: Hashable, Sendable {
    let deviceID: String
    let registeredAt: Date
}

enum RegistrationError: Error, UserFacingError {
    case failed

    var userMessage: String { Strings.Registration.failedMessage }
}

/// Registers the anonymous device ID with the backend. Registration happens
/// once; the call is idempotent (retrying with the same ID is safe).
protocol RegistrationService: Sendable {
    var isRegistered: Bool { get }
    func register(deviceId: String) async throws -> RegistrationResult
}

/// Mock implementation — no real backend yet. Simulates 600–1200ms of network
/// latency and persists the registered flag through the Keychain-backed
/// identity store. `-failRegistration` (QA) makes the first attempt fail so
/// the retry path can be exercised.
final class MockRegistrationService: RegistrationService, @unchecked Sendable {

    private let deviceIdentity: DeviceIdentityProviding
    private let lock = NSLock()
    private var didSimulateFailure = false

    init(deviceIdentity: DeviceIdentityProviding) {
        self.deviceIdentity = deviceIdentity
    }

    var isRegistered: Bool {
        deviceIdentity.isRegistered()
    }

    func register(deviceId: String) async throws -> RegistrationResult {
        // Simulated network latency (600–1200ms).
        let latency = UInt64.random(in: 600_000_000...1_200_000_000)
        try? await Task.sleep(nanoseconds: latency)

        if ProcessInfo.processInfo.arguments.contains("-failRegistration") {
            lock.lock()
            let shouldFail = !didSimulateFailure
            didSimulateFailure = true
            lock.unlock()
            if shouldFail { throw RegistrationError.failed }
        }

        deviceIdentity.setRegistered(true)
        return RegistrationResult(deviceID: deviceId, registeredAt: Date())
    }
}
