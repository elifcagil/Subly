import UIKit

@MainActor
final class OnboardingCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    /// Reports how onboarding ended so the app can route the follow-up
    /// (open the Add flow after "Add your first subscription").
    var onFinished: ((OnboardingViewModel.Outcome) -> Void)?

    private let window: UIWindow
    private let container: AppContainer

    init(window: UIWindow, container: AppContainer) {
        self.window = window
        self.container = container
    }

    func start() {
        let viewModel = OnboardingViewModel(sampleDataSeeder: container.sampleDataSeeder)
        viewModel.onCompleted = { [weak self] outcome in
            self?.container.hapticsService.play(.success)
            self?.onFinished?(outcome)
        }
        let viewController = OnboardingViewController(
            viewModel: viewModel,
            haptics: container.hapticsService
        )
        window.rootViewController = viewController
    }
}
