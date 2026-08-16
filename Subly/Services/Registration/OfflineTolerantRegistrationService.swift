import Foundation

/// Keeps the one-time registration gate (00B → 00C) from becoming a wall the
/// user cannot get past.
///
/// Registration is a bookkeeping call: the device ID already exists in the
/// Keychain and every feature works without the backend knowing about it. So a
/// connectivity failure must not block launch — the gate lets the user through,
/// records that the backend has not acknowledged the device yet, and the call
/// is retried on the next foreground until it lands.
///
/// Only genuine connectivity failures are absorbed. Anything else (a bad
/// configuration, a rejected request, the `-failRegistration` QA flag) still
/// propagates, so `RegisteringViewModel` keeps showing its message + retry.
struct OfflineTolerantRegistrationService: RegistrationService {

    private let wrapped: RegistrationService
    private let deviceIdentity: DeviceIdentityProviding
    private let logger: Logging

    init(wrapping wrapped: RegistrationService, deviceIdentity: DeviceIdentityProviding, logger: Logging) {
        self.wrapped = wrapped
        self.deviceIdentity = deviceIdentity
        self.logger = logger
    }

    var isRegistered: Bool { deviceIdentity.isRegistered() }

    func register(deviceId: String) async throws -> RegistrationResult {
        do {
            let result = try await wrapped.register(deviceId: deviceId)
            deviceIdentity.setPendingRemoteSync(false)
            return result
        } catch let error where Self.isConnectivityFailure(error) {
            logger.warning(
                "Device registration deferred — no connectivity. Will retry on next foreground. (\(error))",
                category: "registration"
            )
            deviceIdentity.setRegistered(true)
            deviceIdentity.setPendingRemoteSync(true)
            return RegistrationResult(deviceID: deviceId, registeredAt: Date())
        }
    }

    /// `URLError` covers URLSession failures directly; the `NSError` check
    /// catches the same failures after a client library has re-boxed them.
    private static func isConnectivityFailure(_ error: Error) -> Bool {
        if error is URLError { return true }
        return (error as NSError).domain == NSURLErrorDomain
    }
}
