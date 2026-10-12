import UIKit

@MainActor
final class TabBarCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let container: AppContainer
    private let tabBarController = UITabBarController()
    private let floatingBar = SublyTabBar()
    private let fab = SublyFloatingActionButton()
    /// Index of the Subscriptions tab — where notification deep links land.
    private let subscriptionsTabIndex = 1

    init(window: UIWindow, container: AppContainer) {
        self.window = window
        self.container = container
    }

    func start() {
        // Floating pill with 3 roots — Home · Subs · Timeline — plus a
        // separate circular accent FAB that opens Add. Settings is reached
        // from the Dashboard header button. (Search tab dropped: the list has
        // its own search field.)
        let dashboardNav = makeNavigation()
        let dashboardCoordinator = DashboardCoordinator(
            navigationController: dashboardNav,
            container: container
        )

        let listNav = makeNavigation()
        let listCoordinator = SubscriptionListCoordinator(
            navigationController: listNav,
            container: container
        )

        let timelineNav = makeNavigation()
        let timelineCoordinator = TimelineCoordinator(
            navigationController: timelineNav,
            container: container
        )

        addChild(dashboardCoordinator)
        addChild(listCoordinator)
        addChild(timelineCoordinator)

        dashboardCoordinator.start()
        listCoordinator.start()
        timelineCoordinator.start()

        tabBarController.viewControllers = [dashboardNav, listNav, timelineNav]
        tabBarController.tabBar.isHidden = true
        installFloatingBar()
        applyStartTabIfRequested()
        window.rootViewController = tabBarController
        installNotificationDeepLink()
    }

    // MARK: - Notification permission (entry prompt)

    /// Asks for notification permission once, the first time the main shell
    /// is on screen with the OS status still undetermined. A pre-prompt
    /// explains why; "Allow" shows the system dialog. Granted → the Settings
    /// switch turns on and reminders are scheduled; denied → a short pointer
    /// to iOS Settings. Skipped (and retried next time) while a sheet is up.
    func promptForNotificationPermissionIfNeeded(after delay: TimeInterval = 0) {
        let service = container.notificationPermissionService
        Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard let self, await service.shouldPromptOnEntry() else { return }
            guard self.tabBarController.presentedViewController == nil else { return }
            service.markPromptedOnEntry()

            let alert = UIAlertController(
                title: Strings.Onboarding.notificationsTitle,
                message: Strings.Onboarding.notificationsMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: Strings.NotificationPermission.notNow, style: .cancel))
            let allow = UIAlertAction(title: Strings.Onboarding.allowNotifications, style: .default) { [weak self] _ in
                Task { @MainActor [weak self] in
                    let granted = await service.requestPermission()
                    if granted {
                        self?.container.hapticsService.play(.success)
                    } else {
                        self?.presentNotificationPermissionDeniedAlert()
                    }
                }
            }
            alert.addAction(allow)
            alert.preferredAction = allow
            self.tabBarController.present(alert, animated: true)
        }
    }

    private func presentNotificationPermissionDeniedAlert() {
        let host = tabBarController.topPresentedController ?? tabBarController
        let alert = UIAlertController(
            title: Strings.NotificationPermission.deniedTitle,
            message: Strings.NotificationPermission.deniedMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.Common.ok, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.NotificationPermission.openSettings, style: .default) { [weak self] _ in
            self?.container.notificationPermissionService.markAwaitingSystemSettings()
            UIApplication.openNotificationSettings()
        })
        host.present(alert, animated: true)
    }

    // MARK: - Deep links (notification taps, widgets, `subly://` URLs)

    private func installNotificationDeepLink() {
        DeepLinkRouter.shared.onOpenSubscription = { [weak self] id in
            self?.openSubscription(id)
        }
        DeepLinkRouter.shared.onAddSubscription = { [weak self] in
            guard let self else { return }
            self.tabBarController.presentedViewController?.dismiss(animated: false)
            self.presentAddFlow()
        }
        DeepLinkRouter.shared.onOpenRecap = { [weak self] index in
            self?.presentRecap(index: index)
        }
    }

    /// Notification tap / `subly://recap[/n]`: the requested recap, or the
    /// latest due one.
    func presentRecap(index: Int?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let scheduler = self.container.recapScheduler
            let recap: Recap?
            if let index { recap = await scheduler.recap(index: index) } else { recap = await scheduler.latestDueRecap() }
            guard let recap else { return }
            let host = self.tabBarController.topPresentedController ?? self.tabBarController
            let coordinator = RecapCoordinator(presentingController: host, container: self.container, recap: recap)
            coordinator.onFinished = { [weak self, weak coordinator] in
                guard let self, let coordinator else { return }
                self.removeChild(coordinator)
            }
            self.addChild(coordinator)
            coordinator.start()
        }
    }

    private func openSubscription(_ id: UUID) {
        Task { @MainActor [weak self] in
            guard let self,
                  let subscription = try? await self.container.subscriptionRepository.subscription(with: id),
                  let nav = self.tabBarController.viewControllers?[self.subscriptionsTabIndex] as? UINavigationController
            else { return }
            self.tabBarController.presentedViewController?.dismiss(animated: false)
            self.tabBarController.selectedIndex = self.subscriptionsTabIndex
            self.floatingBar.setSelectedIndex(self.subscriptionsTabIndex, notify: false)
            nav.popToRootViewController(animated: false)

            let coordinator = SubscriptionDetailCoordinator(
                navigationController: nav,
                container: self.container,
                subscription: subscription
            )
            coordinator.onFinished = { [weak self, weak coordinator] in
                guard let self, let coordinator else { return }
                self.removeChild(coordinator)
            }
            self.addChild(coordinator)
            coordinator.start()
        }
    }

    private func installFloatingBar() {
        guard let host = tabBarController.view else { return }

        floatingBar.translatesAutoresizingMaskIntoConstraints = false
        floatingBar.configure(items: [
            .init(title: Strings.Tabs.dashboard, systemIcon: "house"),
            .init(title: Strings.Tabs.subscriptions, systemIcon: "list.bullet"),
            .init(title: Strings.Tabs.timeline, systemIcon: "calendar")
        ])
        floatingBar.onSelect = { [weak self] index in
            self?.container.hapticsService.play(.selection)
            self?.tabBarController.selectedIndex = index
        }

        fab.addTarget(self, action: #selector(didTapFab), for: .touchUpInside)

        host.addSubview(floatingBar)
        host.addSubview(fab)

        let inset = DesignSystem.Spacing.barInset
        NSLayoutConstraint.activate([
            floatingBar.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: inset),
            floatingBar.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            fab.leadingAnchor.constraint(equalTo: floatingBar.trailingAnchor, constant: 12),
            fab.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -inset),
            fab.centerYAnchor.constraint(equalTo: floatingBar.centerYAnchor)
        ])

        // Keep scrollable content clear of the floating chrome.
        tabBarController.viewControllers?.forEach {
            $0.additionalSafeAreaInsets.bottom = 58 + 30
        }
    }

    @objc private func didTapFab() {
        container.hapticsService.play(.lightImpact)
        presentAddFlow()
    }

    /// Also called by AppCoordinator right after onboarding's
    /// "Add your first subscription".
    func presentAddFlow() {
        guard let host = tabBarController.selectedViewController?.topPresentedController
            ?? tabBarController.selectedViewController else { return }
        let coordinator = CatalogPickerCoordinator(presentingController: host, container: container)
        var didSelect = false
        coordinator.onSelection = { [weak self] selection in
            didSelect = true
            self?.handleCatalogSelection(selection)
        }
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
            // Closed without picking anything → the form never opened, so
            // this is the moment to ask (first-run add flow).
            if !didSelect {
                self.promptForNotificationPermissionIfNeeded(after: 0.4)
            }
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func handleCatalogSelection(_ selection: CatalogPickerSelection) {
        guard let host = tabBarController.selectedViewController?.topPresentedController
            ?? tabBarController.selectedViewController else { return }
        let mode: AddEditSubscriptionViewModel.Mode
        switch selection {
        case .manual: mode = .create
        case .catalog(let entry): mode = .createFromCatalog(entry)
        }
        let coordinator = AddEditSubscriptionCoordinator(
            presentingController: host,
            container: container,
            mode: mode
        )
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
            // First subscription saved (or form dismissed): ask now, when a
            // reminder is something concrete.
            self.promptForNotificationPermissionIfNeeded(after: 0.4)
        }
        addChild(coordinator)
        coordinator.start()
    }

    /// Visual-QA helper: `-startTab N` selects a tab on launch;
    /// `-previewCatalog` opens the Add sheet.
    private func applyStartTabIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startTab"), i + 1 < args.count,
           let index = Int(args[i + 1]) {
            let count = tabBarController.viewControllers?.count ?? 0
            if index >= 0 && index < count {
                tabBarController.selectedIndex = index
                floatingBar.setSelectedIndex(index, notify: false)
            }
        }
        if args.contains("-previewCatalog") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.presentAddFlow()
            }
        }
        if args.contains("-previewCustomForm") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.handleCatalogSelection(.manual)
            }
        }
        if args.contains("-previewPrefilledForm") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let entry = CatalogEntry.defaults.first else { return }
                self?.handleCatalogSelection(.catalog(entry))
            }
        }
    }

    private func makeNavigation() -> UINavigationController {
        let nav = UINavigationController()
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }
}

private extension UIViewController {
    /// Walks to the top of the presented-controller chain.
    var topPresentedController: UIViewController? {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
