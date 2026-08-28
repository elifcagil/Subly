import UIKit

@MainActor
final class AddEditSubscriptionCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let presentingController: UIViewController
    private let container: AppContainer
    private let mode: AddEditSubscriptionViewModel.Mode
    private weak var modalNavigationController: UINavigationController?

    init(
        presentingController: UIViewController,
        container: AppContainer,
        mode: AddEditSubscriptionViewModel.Mode = .create
    ) {
        self.presentingController = presentingController
        self.container = container
        self.mode = mode
    }

    func start() {
        let viewModel = AddEditSubscriptionViewModel(
            mode: mode,
            subscriptionRepository: container.subscriptionRepository,
            categoryRepository: container.categoryRepository,
            notificationScheduler: container.notificationManager,
            preferences: container.settingsPreferences,
            calendarService: container.calendarService,
            currencyManager: container.currencyManager,
            currencyFormatter: container.currencyFormatter,
            dateProvider: container.dateProvider,
            defaultCurrencyCode: container.currencyManager.preferredDisplayCurrency.code
        )
        viewModel.onCancelled = { [weak self] in
            self?.dismiss()
        }
        viewModel.onSaved = { [weak self] in
            self?.container.hapticsService.play(.success)
            self?.dismiss()
        }
        let viewController = AddEditSubscriptionViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        viewController.onPickCurrencyRequested = { [weak self, weak viewController] currentCode in
            guard let self, let host = viewController else { return }
            self.presentCurrencyPicker(from: host, currentCode: currentCode) { code in
                viewModel.updateCurrencyCode(code)
            }
        }
        let nav = UINavigationController(rootViewController: viewController)
        nav.modalPresentationStyle = .fullScreen
        modalNavigationController = nav
        presentingController.present(nav, animated: true)
    }

    private func presentCurrencyPicker(
        from host: UIViewController,
        currentCode: String,
        onSelect: @escaping (String) -> Void
    ) {
        let coordinator = CurrencyPickerCoordinator(
            presentingController: host,
            container: container,
            initiallySelectedCode: currentCode
        )
        coordinator.onSelection = { code in
            onSelect(code)
        }
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func dismiss() {
        modalNavigationController?.dismiss(animated: true) { [weak self] in
            self?.onFinished?()
        }
    }
}
