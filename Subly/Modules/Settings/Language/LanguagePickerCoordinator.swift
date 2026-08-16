import UIKit

@MainActor
final class LanguagePickerCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let navigationController: UINavigationController
    private let container: AppContainer

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = LanguagePickerViewModel(localizationManager: container.localizationManager)
        let viewController = LanguagePickerViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        navigationController.pushViewController(viewController, animated: true)
    }
}
