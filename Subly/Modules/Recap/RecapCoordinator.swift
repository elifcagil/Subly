import UIKit

/// Presents the story full screen (`.overFullScreen`) from whatever is on top.
@MainActor
final class RecapCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private weak var presentingController: UIViewController?
    private let container: AppContainer
    private let recap: Recap
    private weak var viewController: StoryViewController?
    private var zoomTransition: RecapZoomTransition?
    private var content: RecapStoryContent?

    init(presentingController: UIViewController, container: AppContainer, recap: Recap, sourceView: UIView? = nil) {
        self.presentingController = presentingController
        self.container = container
        self.recap = recap
        self.zoomTransition = sourceView.map(RecapZoomTransition.init(sourceView:))
    }

    func start() {
        let viewModel = RecapViewModel(
            recap: recap,
            periodLabel: container.recapScheduler.periodLabel(for: recap),
            currencyFormatter: container.currencyFormatter,
            calendar: container.dateProvider.calendar
        )
        viewModel.onSeen = { [weak self] recap in
            self?.container.recapScheduler.markSeen(recap)
        }
        viewModel.onDismiss = { [weak self] in
            self?.dismiss()
        }
        viewModel.onShare = { [weak self] in
            self?.share()
        }
        viewModel.onReviewSubscriptions = { [weak self] in
            self?.dismiss {
                // Subscriptions tab; v1 has no price-history filter yet.
                self?.presentingController?.tabBarController?.selectedIndex = 1
            }
        }
        let content = RecapStoryContent(viewModel: viewModel, haptics: container.hapticsService)
        let viewController = StoryViewController(content: content, haptics: container.hapticsService)
        self.content = content
        viewController.modalPresentationStyle = .overFullScreen
        viewController.modalPresentationCapturesStatusBarAppearance = true
        // Zoom from the header story icon when opened from the Dashboard.
        viewController.transitioningDelegate = zoomTransition
        self.viewController = viewController
        presentingController?.present(viewController, animated: true)
    }

    private func share() {
        guard let viewController else { return }
        let image = RecapShareRenderer.render(
            recap: recap,
            periodLabel: container.recapScheduler.periodLabel(for: recap),
            currencyFormatter: container.currencyFormatter
        )
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activity.completionWithItemsHandler = { [weak viewController] _, _, _, _ in
            viewController?.resume()
        }
        viewController.present(activity, animated: true)
    }

    private func dismiss(completion: (() -> Void)? = nil) {
        viewController?.dismiss(animated: true) { [weak self] in
            completion?()
            self?.onFinished?()
        }
    }
}
