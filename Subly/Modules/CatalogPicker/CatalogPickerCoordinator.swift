import UIKit

@MainActor
final class CatalogPickerCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onSelection: ((CatalogPickerSelection) -> Void)?
    var onFinished: (() -> Void)?

    private let presentingController: UIViewController
    private let container: AppContainer
    private weak var modalNavigationController: UINavigationController?

    init(presentingController: UIViewController, container: AppContainer) {
        self.presentingController = presentingController
        self.container = container
    }

    func start() {
        let viewModel = CatalogPickerViewModel(catalogRepository: container.catalogRepository)
        viewModel.onSelected = { [weak self] selection in
            self?.modalNavigationController?.dismiss(animated: true) {
                self?.onSelection?(selection)
                self?.onFinished?()
            }
        }
        viewModel.onCancelled = { [weak self] in
            self?.modalNavigationController?.dismiss(animated: true) {
                self?.onFinished?()
            }
        }
        let viewController = CatalogPickerViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        let nav = UINavigationController(rootViewController: viewController)
        nav.modalPresentationStyle = .fullScreen
        modalNavigationController = nav
        presentingController.present(nav, animated: true)
    }
}
