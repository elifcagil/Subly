import UIKit

@MainActor
final class FinancialLoadCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let navigationController: UINavigationController
    private let container: AppContainer
    private let initialCurrencyCode: String?
    private weak var pushedViewController: UIViewController?

    init(
        navigationController: UINavigationController,
        container: AppContainer,
        initialCurrencyCode: String? = nil
    ) {
        self.navigationController = navigationController
        self.container = container
        self.initialCurrencyCode = initialCurrencyCode
    }

    func start() {
        let viewModel = FinancialLoadViewModel(
            subscriptionRepository: container.subscriptionRepository,
            currencyFormatter: container.currencyFormatter,
            currencyManager: container.currencyManager,
            dateProvider: container.dateProvider,
            initialCurrencyCode: initialCurrencyCode
        )
        let viewController = FinancialLoadViewController(viewModel: viewModel)
        pushedViewController = viewController
        navigationController.pushViewController(viewController, animated: true)
    }
}
