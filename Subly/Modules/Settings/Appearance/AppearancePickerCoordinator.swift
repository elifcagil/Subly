import UIKit

@MainActor
final class AppearancePickerCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let navigationController: UINavigationController
    private let container: AppContainer

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = AppearancePickerViewModel(themeManager: container.themeManager)
        let viewController = AppearancePickerViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        navigationController.pushViewController(viewController, animated: true)
    }
}
