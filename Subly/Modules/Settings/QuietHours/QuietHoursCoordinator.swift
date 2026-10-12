import UIKit

@MainActor
final class QuietHoursCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let container: AppContainer
    private weak var viewModel: QuietHoursViewModel?

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = QuietHoursViewModel(
            service: container.quietHoursService,
            deviceProfile: container.deviceProfileService,
            calendar: container.dateProvider.calendar
        )
        self.viewModel = viewModel
        let viewController = QuietHoursViewController(viewModel: viewModel, haptics: container.hapticsService)
        viewController.onOpenPicker = { [weak self, weak viewController] tab in
            guard let self, let viewController, let viewModel = self.viewModel else { return }
            let picker = QuietHoursTimePickerViewController(viewModel: viewModel, tab: tab)
            picker.onSet = { start, end in viewModel.setRange(startMinutes: start, endMinutes: end) }
            viewController.present(picker, animated: true)
        }
        viewController.onOpenDays = { [weak self] in
            guard let self, let viewModel = self.viewModel else { return }
            let days = QuietHoursWeekdaysViewController(selected: viewModel.value.weekdays, calendar: self.container.dateProvider.calendar)
            days.onChange = { viewModel.setWeekdays($0) }
            self.navigationController.pushViewController(days, animated: true)
        }
        navigationController.pushViewController(viewController, animated: true)
    }
}
