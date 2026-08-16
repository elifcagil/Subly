import UIKit

@MainActor
final class InsightsCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let container: AppContainer

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = InsightsViewModel(
            subscriptionRepository: container.subscriptionRepository,
            categoryRepository: container.categoryRepository,
            currencyFormatter: container.currencyFormatter,
            currencyManager: container.currencyManager,
            dateProvider: container.dateProvider
        )
        let viewController = InsightsViewController(viewModel: viewModel)
        // Insights is now reached by pushing from the Dashboard hero (handoff:
        // it is not a tab root).
        navigationController.pushViewController(viewController, animated: true)
    }
}
