import UIKit

@MainActor
final class ReminderDefaultsCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let navigationController: UINavigationController
    private let container: AppContainer

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = ReminderDefaultsViewModel(preferences: container.settingsPreferences)
        let viewController = ReminderDefaultsViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        navigationController.pushViewController(viewController, animated: true)
    }
}
