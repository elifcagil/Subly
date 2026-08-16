import UIKit

@MainActor
final class SubscriptionDetailCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let navigationController: UINavigationController
    private let container: AppContainer
    private let subscription: Subscription
    private weak var detailViewController: SubscriptionDetailViewController?

    init(
        navigationController: UINavigationController,
        container: AppContainer,
        subscription: Subscription
    ) {
        self.navigationController = navigationController
        self.container = container
        self.subscription = subscription
    }

    func start() {
        let viewModel = SubscriptionDetailViewModel(
            subscription: subscription,
            subscriptionRepository: container.subscriptionRepository,
            categoryRepository: container.categoryRepository,
            notificationScheduler: container.notificationManager,
            currencyFormatter: container.currencyFormatter,
            dateProvider: container.dateProvider,
            preferences: container.settingsPreferences
        )
        viewModel.onEditRequested = { [weak self] subscription in
            self?.presentEdit(for: subscription)
        }
        viewModel.onDismiss = { [weak self] in
            self?.popDetail()
        }
        viewModel.onReminderSheetRequested = { [weak self, weak viewModel] currentLeadDays in
            self?.presentReminderSheet(currentLeadDays: currentLeadDays) { leadDays in
                viewModel?.setReminder(leadDays: leadDays)
            }
        }
        let viewController = SubscriptionDetailViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        detailViewController = viewController
        navigationController.pushViewController(viewController, animated: true)
    }

    private func presentEdit(for subscription: Subscription) {
        guard let host = detailViewController else { return }
        let coordinator = AddEditSubscriptionCoordinator(
            presentingController: host,
            container: container,
            mode: .edit(subscription)
        )
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }

    /// v5 screen 13 — medium-detent reminder sheet over the detail.
    private func presentReminderSheet(currentLeadDays: Int?, onDone: @escaping (Int) -> Void) {
        guard let host = detailViewController else { return }
        let sheet = ReminderSheetViewController(
            selectedLeadDays: currentLeadDays,
            haptics: container.hapticsService
        )
        sheet.onDone = onDone
        host.present(sheet, animated: true)
    }

    private func popDetail() {
        if navigationController.topViewController === detailViewController {
            navigationController.popViewController(animated: true)
        }
        onFinished?()
    }
}
