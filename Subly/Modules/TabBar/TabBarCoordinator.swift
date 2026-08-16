import UIKit

@MainActor
final class TabBarCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let container: AppContainer
    private let tabBarController = UITabBarController()
    private let floatingBar = SublyTabBar()
    private let fab = SublyFloatingActionButton()

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
        coordinator.onSelection = { [weak self] selection in
            self?.handleCatalogSelection(selection)
        }
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
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
