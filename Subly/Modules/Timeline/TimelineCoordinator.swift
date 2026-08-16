import UIKit

@MainActor
final class TimelineCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let container: AppContainer

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = TimelineViewModel(
            subscriptionRepository: container.subscriptionRepository,
            categoryRepository: container.categoryRepository,
            currencyFormatter: container.currencyFormatter,
            dateProvider: container.dateProvider
        )
        viewModel.onSelectSubscription = { [weak self] subscription in
            self?.showDetail(for: subscription)
        }
        let viewController = TimelineViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        navigationController.setViewControllers([viewController], animated: false)
    }

    private func showDetail(for subscription: Subscription) {
        let coordinator = SubscriptionDetailCoordinator(
            navigationController: navigationController,
            container: container,
            subscription: subscription
        )
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }
}
