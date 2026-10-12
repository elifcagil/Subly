import UIKit

/// Presents the What's New story full screen (`.overFullScreen`) over
/// whatever is on top: automatically on the first launch after an update,
/// or from Settings → What's new.
@MainActor
final class WhatsNewCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFinished: (() -> Void)?

    private weak var presentingController: UIViewController?
    private let container: AppContainer
    private let payload: WhatsNewPayload
    private weak var viewController: StoryViewController?
    private var content: WhatsNewViewModel?

    init(presentingController: UIViewController, container: AppContainer, payload: WhatsNewPayload) {
        self.presentingController = presentingController
        self.container = container
        self.payload = payload
    }

    /// The story for the running version, if this build ships one and the
    /// release switch is on.
    static func currentPayload() -> WhatsNewPayload? {
        WhatsNewPayload.active
    }

    func start() {
        start(animated: true)
    }

    func start(animated: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let nextRecap = await container.recapScheduler.nextRecapDate()
            let firstRecapDate = nextRecap.map {
                WhatsNewViewModel.formatFirstRecapDate($0, calendar: container.dateProvider.calendar)
            }
            let viewModel = WhatsNewViewModel(payload: payload, firstRecapDate: firstRecapDate)
            viewModel.onSeen = { [weak self] version in
                self?.container.whatsNewStore.markSeen(version: version)
            }
            viewModel.onDismiss = { [weak self] in
                self?.dismiss()
            }
            self.content = viewModel
            let viewController = StoryViewController(content: viewModel, haptics: container.hapticsService)
            viewController.modalPresentationStyle = .overFullScreen
            viewController.modalPresentationCapturesStatusBarAppearance = true
            self.viewController = viewController
            presentingController?.present(viewController, animated: animated)
        }
    }

    private func dismiss() {
        viewController?.dismiss(animated: true) { [weak self] in
            self?.onFinished?()
        }
    }
}
