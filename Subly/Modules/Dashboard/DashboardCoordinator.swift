import UIKit

@MainActor
final class DashboardCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let container: AppContainer

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = DashboardViewModel(
            subscriptionRepository: container.subscriptionRepository,
            categoryRepository: container.categoryRepository,
            currencyFormatter: container.currencyFormatter,
            currencyManager: container.currencyManager,
            dateProvider: container.dateProvider,
            sampleDataSeeder: container.sampleDataSeeder
        )
        viewModel.onAddSubscriptionTapped = { [weak self] in
            self?.presentCatalogPicker()
        }
        viewModel.onSelectSubscription = { [weak self] subscription in
            self?.showDetail(for: subscription)
        }
        viewModel.onPressureCardTapped = { [weak self] currencyCode in
            self?.showFinancialLoad(currencyCode: currencyCode)
        }
        viewModel.onSeeAllUpcomingTapped = { [weak self] in
            // Switch to the Subscriptions tab root.
            self?.navigationController.tabBarController?.selectedIndex = 1
        }
        viewModel.onShowInsights = { [weak self] in
            self?.showInsights()
        }
        viewModel.onShowSettings = { [weak self] in
            self?.showSettings()
        }
        let viewController = DashboardViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        navigationController.setViewControllers([viewController], animated: false)
    }

    private func presentCatalogPicker() {
        guard let host = navigationController.topViewController else { return }
        let coordinator = CatalogPickerCoordinator(presentingController: host, container: container)
        coordinator.onSelection = { [weak self] selection in
            self?.handleCatalogSelection(selection)
        }
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func handleCatalogSelection(_ selection: CatalogPickerSelection) {
        let mode: AddEditSubscriptionViewModel.Mode
        switch selection {
        case .manual: mode = .create
        case .catalog(let entry): mode = .createFromCatalog(entry)
        }
        presentAddEditFlow(mode: mode)
    }

    private func presentAddEditFlow(mode: AddEditSubscriptionViewModel.Mode) {
        guard let host = navigationController.topViewController else { return }
        let coordinator = AddEditSubscriptionCoordinator(
            presentingController: host,
            container: container,
            mode: mode
        )
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func showSettings() {
        // v5: Settings is not a tab — pushed from the Dashboard header avatar.
        let coordinator = SettingsCoordinator(
            navigationController: navigationController,
            container: container
        )
        addChild(coordinator)
        coordinator.start()
    }

    private func showInsights() {
        let coordinator = InsightsCoordinator(
            navigationController: navigationController,
            container: container
        )
        addChild(coordinator)
        coordinator.start()
    }

    private func showFinancialLoad(currencyCode: String) {
        let coordinator = FinancialLoadCoordinator(
            navigationController: navigationController,
            container: container,
            initialCurrencyCode: currencyCode
        )
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
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
