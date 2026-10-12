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
            dateProvider: container.dateProvider,
            recapProvider: container.recapScheduler
        )
        viewModel.onSelectSubscription = { [weak self] subscription in
            self?.showDetail(for: subscription)
        }
        viewModel.onOpenRecap = { [weak self] index in
            self?.presentRecap(index: index)
        }
        let viewController = TimelineViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        navigationController.setViewControllers([viewController], animated: false)
    }

    private func presentRecap(index: Int) {
        Task { @MainActor [weak self] in
            guard let self, let host = self.navigationController.topViewController,
                  let recap = await self.container.recapScheduler.recap(index: index) else { return }
            let coordinator = RecapCoordinator(presentingController: host, container: self.container, recap: recap)
            coordinator.onFinished = { [weak self, weak coordinator] in
                guard let self, let coordinator else { return }
                self.removeChild(coordinator)
            }
            self.addChild(coordinator)
            coordinator.start()
        }
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
