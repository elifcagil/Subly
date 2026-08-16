import UIKit
import AuthenticationServices

@MainActor
final class AccountCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let navigationController: UINavigationController
    private let container: AppContainer
    private weak var hostController: AccountViewController?

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = AccountViewModel(
            authService: container.authService,
            storeKitService: container.storeKitService
        )
        viewModel.onSignInRequested = { [weak self] in
            self?.presentSignIn(using: viewModel)
        }
        let viewController = AccountViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        hostController = viewController
        navigationController.pushViewController(viewController, animated: true)
    }

    private func presentSignIn(using viewModel: AccountViewModel) {
        guard let anchor = hostController?.view.window else { return }
        Task { [weak self, container] in
            do {
                _ = try await container.authService.signInWithApple(presentationAnchor: anchor)
                container.hapticsService.play(.success)
            } catch let error as UserFacingError {
                viewModel.onErrorMessage?(error.userMessage)
                _ = self
            } catch {
                viewModel.onErrorMessage?("Sign in didn't complete.")
            }
        }
    }
}
