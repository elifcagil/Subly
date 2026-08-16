import Foundation

/// v5 Registering (screen 00C): runs the (idempotent) register call with a
/// minimum ~800ms display so the screen never flashes, then hands off to the
/// main flow. On failure it stays put with a calm message + "Try again".
@MainActor
final class RegisteringViewModel {

    enum State: Equatable {
        case working
        case succeeded
        case failed(message: String)
    }

    private let registrationService: RegistrationService
    private let deviceIdentity: DeviceIdentityProviding
    /// Minimum time the screen stays visible (spec: ~800ms, never flashes).
    private let minimumDisplay: Duration = .milliseconds(800)

    private(set) var state: State = .working {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((State) -> Void)?
    var onFinished: (() -> Void)?

    init(registrationService: RegistrationService, deviceIdentity: DeviceIdentityProviding) {
        self.registrationService = registrationService
        self.deviceIdentity = deviceIdentity
    }

    func start() {
        runRegistration()
    }

    /// Retries with the same device ID — the call is idempotent.
    func retry() {
        guard case .failed = state else { return }
        state = .working
        runRegistration()
    }

    private func runRegistration() {
        let deviceID = deviceIdentity.deviceID()
        Task { [weak self] in
            guard let self else { return }
            async let minimumHold: Void? = try? Task.sleep(for: minimumDisplay)
            do {
                _ = try await registrationService.register(deviceId: deviceID)
                _ = await minimumHold
                self.state = .succeeded
                // A short beat with the check badge visible before routing.
                try? await Task.sleep(for: .milliseconds(600))
                self.onFinished?()
            } catch let error as UserFacingError {
                _ = await minimumHold
                self.state = .failed(message: error.userMessage)
            } catch {
                _ = await minimumHold
                self.state = .failed(message: Strings.Registration.failedMessage)
            }
        }
    }
}
