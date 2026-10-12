import UIKit

@MainActor
final class SettingsCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let container: AppContainer

    init(navigationController: UINavigationController, container: AppContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = SettingsViewModel(
            themeManager: container.themeManager,
            localizationManager: container.localizationManager,
            currencyManager: container.currencyManager,
            preferences: container.settingsPreferences,
            calendarService: container.calendarService,
            permissionService: container.notificationPermissionService,
            reminderSync: container.reminderSyncService,
            quietHoursService: container.quietHoursService,
            storeKitService: container.storeKitService,
            authService: container.authService,
            subscriptionRepository: container.subscriptionRepository,
            featureFlagService: container.featureFlagService,
            deviceIdentity: container.deviceIdentity
        )
        viewModel.onOpenPaywall = { [weak self] in
            self?.presentPaywall()
        }
        viewModel.onOpenAccount = { [weak self] in
            self?.pushAccount()
        }
        viewModel.onOpenAppearance = { [weak self] in
            self?.pushAppearance()
        }
        viewModel.onOpenLanguage = { [weak self] in
            self?.pushLanguage()
        }
        viewModel.onOpenCurrency = { [weak self] in
            self?.presentCurrencyPicker()
        }
        viewModel.onOpenReminderDefaults = { [weak self] in
            self?.pushReminderDefaults()
        }
        viewModel.onOpenQuietHours = { [weak self] in
            self?.pushQuietHours()
        }
        viewModel.onOpenWhatsNew = { [weak self] in
            self?.presentWhatsNew()
        }
        viewModel.onOpenSystemNotificationSettings = {
            UIApplication.openNotificationSettings()
        }
        viewModel.onNotificationPermissionDenied = { [weak self] in
            self?.presentNotificationPermissionDeniedAlert()
        }
        // `viewModel` is captured weakly: it owns this closure, so a strong
        // capture would retain it forever.
        viewModel.onCopyDeviceID = { [weak self, weak viewModel] deviceID in
            UIPasteboard.general.string = deviceID
            self?.container.hapticsService.play(.success)
            viewModel?.onErrorMessage?(Strings.Settings.deviceIDCopied)
        }
        let viewController = SettingsViewController(viewModel: viewModel)
        // v5: Settings is pushed from the Dashboard header avatar (no tab).
        navigationController.pushViewController(viewController, animated: true)
    }

    /// iOS has notifications off for Subly: explain and offer the shortcut.
    private func presentNotificationPermissionDeniedAlert() {
        guard let host = navigationController.topViewController else { return }
        let alert = UIAlertController(
            title: Strings.NotificationPermission.deniedTitle,
            message: Strings.Settings.notificationsPermissionDenied,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.Common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.NotificationPermission.openSettings, style: .default) { _ in
            UIApplication.openNotificationSettings()
        })
        host.present(alert, animated: true)
    }

    private func presentCurrencyPicker() {
        guard let host = navigationController.topViewController else { return }
        let currentCode = container.currencyManager.preferredDisplayCurrency.code
        let coordinator = CurrencyPickerCoordinator(
            presentingController: host,
            container: container,
            initiallySelectedCode: currentCode
        )
        coordinator.onSelection = { [weak self] code in
            self?.container.currencyManager.setPreferredDisplayCurrency(code)
        }
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func presentPaywall() {
        guard let host = navigationController.topViewController else { return }
        let coordinator = PaywallCoordinator(presentingController: host, container: container)
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func pushAccount() {
        let coordinator = AccountCoordinator(
            navigationController: navigationController,
            container: container
        )
        addChild(coordinator)
        coordinator.start()
    }

    private func pushAppearance() {
        let coordinator = AppearancePickerCoordinator(
            navigationController: navigationController,
            container: container
        )
        addChild(coordinator)
        coordinator.start()
    }

    private func pushLanguage() {
        let coordinator = LanguagePickerCoordinator(
            navigationController: navigationController,
            container: container
        )
        addChild(coordinator)
        coordinator.start()
    }

    private func presentWhatsNew() {
        guard let host = navigationController.topViewController,
              let payload = WhatsNewCoordinator.currentPayload() else { return }
        let coordinator = WhatsNewCoordinator(presentingController: host, container: container, payload: payload)
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func pushQuietHours() {
        let coordinator = QuietHoursCoordinator(navigationController: navigationController, container: container)
        addChild(coordinator)
        coordinator.start()
    }

    private func pushReminderDefaults() {
        let coordinator = ReminderDefaultsCoordinator(
            navigationController: navigationController,
            container: container
        )
        addChild(coordinator)
        coordinator.start()
    }
}
