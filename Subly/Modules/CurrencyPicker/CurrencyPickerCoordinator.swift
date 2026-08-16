import UIKit

@MainActor
final class CurrencyPickerCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?
    var onSelection: ((String) -> Void)?

    private let presentingController: UIViewController
    private let container: AppContainer
    private let initiallySelectedCode: String
    private weak var modalNavigationController: UINavigationController?

    init(
        presentingController: UIViewController,
        container: AppContainer,
        initiallySelectedCode: String
    ) {
        self.presentingController = presentingController
        self.container = container
        self.initiallySelectedCode = initiallySelectedCode
    }

    func start() {
        let viewModel = CurrencyPickerViewModel(
            currencyManager: container.currencyManager,
            initiallySelectedCode: initiallySelectedCode
        )
        viewModel.onSelect = { [weak self] code in
            self?.onSelection?(code)
            self?.dismiss()
        }
        let viewController = CurrencyPickerViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        let nav = UINavigationController(rootViewController: viewController)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large(), .medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DesignSystem.Radius.lg
        }
        modalNavigationController = nav
        presentingController.present(nav, animated: true)
    }

    private func dismiss() {
        modalNavigationController?.dismiss(animated: true) { [weak self] in
            self?.onFinished?()
        }
    }
}
