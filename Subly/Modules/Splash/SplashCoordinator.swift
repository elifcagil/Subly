import UIKit

@MainActor
final class SplashCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private let window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        let viewModel = SplashViewModel()
        viewModel.onFinished = { [weak self] in
            self?.onFinished?()
        }
        let viewController = SplashViewController(viewModel: viewModel)
        window.rootViewController = viewController
    }
}
