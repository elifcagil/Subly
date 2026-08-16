import UIKit

@MainActor
final class PaywallCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let presentingController: UIViewController
    private let container: AppContainer
    private weak var modalNavigation: UINavigationController?

    init(presentingController: UIViewController, container: AppContainer) {
        self.presentingController = presentingController
        self.container = container
    }

    func start() {
        let viewModel = PaywallViewModel(storeKitService: container.storeKitService)
        viewModel.onDismiss = { [weak self] in
            self?.dismiss()
        }
        viewModel.onPurchaseSucceeded = { [weak self] in
            self?.container.hapticsService.play(.success)
            self?.dismiss()
        }
        let viewController = PaywallViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        let nav = UINavigationController(rootViewController: viewController)
        nav.modalPresentationStyle = .pageSheet
        modalNavigation = nav
        presentingController.present(nav, animated: true)
    }

    private func dismiss() {
        modalNavigation?.dismiss(animated: true) { [weak self] in
            self?.onFinished?()
        }
    }
}
