import UIKit

/// One-way registration flow (00B → 00C). Screens are window roots — there is
/// no navigation stack, so they can never be navigated back to. Runs once per
/// device; `AppCoordinator` only starts it when the Keychain says the device
/// is not registered yet.
@MainActor
final class RegistrationCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let window: UIWindow
    private let container: AppContainer

    init(window: UIWindow, container: AppContainer) {
        self.window = window
        self.container = container
    }

    func start() {
        if ProcessInfo.processInfo.arguments.contains("-previewRegistering") {
            // Visual-QA: jump straight to 00C.
            showRegistering()
            return
        }
        showRegister()
    }

    private func showRegister() {
        let viewModel = RegisterViewModel()
        viewModel.onContinue = { [weak self] in
            self?.showRegistering()
        }
        let viewController = RegisterViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        window.rootViewController = viewController
    }

    private func showRegistering() {
        let viewModel = RegisteringViewModel(
            registrationService: container.registrationService,
            deviceIdentity: container.deviceIdentity
        )
        viewModel.onFinished = { [weak self] in
            self?.onFinished?()
        }
        let viewController = RegisteringViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        UIView.transition(
            with: window,
            duration: 0.3,
            options: [.transitionCrossDissolve],
            animations: { self.window.rootViewController = viewController }
        )
    }
}
