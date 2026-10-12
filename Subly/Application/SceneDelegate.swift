import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appCoordinator: AppCoordinator?
    private var container: AppContainer?
    private var previewCoordinators: [Coordinator] = []
    private var themeObservationTask: Task<Void, Never>?
    private var localeObservationTask: Task<Void, Never>?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        // Base fill behind root-controller transitions — never flash black.
        window.backgroundColor = DesignSystem.Colors.background
        let container = AppContainer()
        let coordinator = AppCoordinator(window: window, container: container)

        container.themeManager.apply(to: window)

        self.window = window
        self.container = container
        self.appCoordinator = coordinator

        observeTheme(themeManager: container.themeManager, window: window)
        observeLanguage(localizationManager: container.localizationManager)

        let qaArgs = ProcessInfo.processInfo.arguments
        if qaArgs.contains("-resetRegistration") {
            // Visual-QA: force the registration flow on next launch.
            container.deviceIdentity.setRegistered(false)
        }
        if qaArgs.contains("-resetNotificationPrompt") {
            // Visual-QA: show the entry-time notification prompt again.
            UserDefaults.standard.removeObject(forKey: "com.subly.notifications.entry_prompted")
        }
        if qaArgs.contains("-recapQA") {
            // Visual-QA: pretend the device registered 3 months + 2 days ago so a
            // recap is due, and forget any seen recap.
            let calendar = container.dateProvider.calendar
            if let anchor = calendar.date(byAdding: .month, value: -3, to: container.dateProvider.now),
               let backdated = calendar.date(byAdding: .day, value: -2, to: anchor) {
                container.deviceIdentity.setRegisteredAt(backdated)
            }
            UserDefaults.standard.removeObject(forKey: "com.subly.recap.last_seen_index")
        }
        if qaArgs.contains("-whatsNewQA") {
            // Visual-QA: forget the seen version so the story opens on launch.
            container.whatsNewStore.reset()
        }
        if qaArgs.contains("-rolloverQA") {
            // Visual-QA: insert a stale-dated subscription so the roll-forward
            // pass has something to advance (the UI can't create past dates).
            let repository = container.subscriptionRepository
            let dateProvider = container.dateProvider
            Task { @MainActor in
                let yesterday = dateProvider.calendar.date(
                    byAdding: .day, value: -1, to: dateProvider.now
                ) ?? dateProvider.now
                try? await repository.save(Subscription(
                    name: "RolloverQA",
                    amount: 9.99,
                    currencyCode: "USD",
                    billingCycle: .monthly,
                    startDate: yesterday,
                    nextRenewalDate: yesterday
                ))
            }
        }
        if qaArgs.contains("-skipOnboarding") {
            // Visual-QA: straight to the (possibly empty) main shell.
            UserDefaults.standard.set(true, forKey: "com.subly.onboarding.completed")
            container.deviceIdentity.setRegistered(true)
        }
        if DebugSampleData.isRequested {
            // Visual-QA path: land past registration + onboarding, seed, start.
            container.deviceIdentity.setRegistered(true)
            UserDefaults.standard.set(true, forKey: "com.subly.onboarding.completed")
            Task { @MainActor in
                await DebugSampleData.seedIfNeeded(into: container)
                if qaArgs.contains("-recapQA") {
                    // Backdate start dates so the sample subscriptions existed for
                    // the whole first recap period.
                    let calendar = container.dateProvider.calendar
                    for var sub in (try? await container.subscriptionRepository.fetchAll()) ?? [] {
                        guard let earlier = calendar.date(byAdding: .month, value: -8, to: sub.startDate) else { continue }
                        sub.startDate = earlier
                        sub.createdAt = calendar.date(byAdding: .day, value: -2, to: anchorQA(calendar, container)) ?? earlier
                        try? await container.subscriptionRepository.save(sub)
                    }
                }
                coordinator.start()
                await self.presentPreviewIfRequested(container: container)
            }
        } else {
            coordinator.start()
        }
        window.makeKeyAndVisible()

        // `subly://…` from a widget tap that launched the app.
        for context in connectionOptions.urlContexts {
            DeepLinkRouter.shared.open(context.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            DeepLinkRouter.shared.open(context.url)
        }
    }

    /// `-recapQA`: 3 months ago, so the first recap is due.
    private func anchorQA(_ calendar: Calendar, _ container: AppContainer) -> Date {
        calendar.date(byAdding: .month, value: -3, to: container.dateProvider.now) ?? container.dateProvider.now
    }

    /// Visual-QA: `-previewDetail` pushes the first subscription's detail;
    /// `-previewPaywall` presents the paywall. Used only with `-seedSampleData`.
    @MainActor
    private func presentPreviewIfRequested(container: AppContainer) async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-previewDetail")
            || args.contains("-previewPaywall")
            || args.contains("-previewSettings") else { return }

        // Wait for the main shell to replace the splash as the window root.
        var tabBar: UITabBarController?
        for _ in 0..<40 {
            if let tb = window?.rootViewController as? UITabBarController { tabBar = tb; break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        guard let tabBar else { return }

        if args.contains("-previewDetail") {
            tabBar.selectedIndex = 1
            if let nav = tabBar.selectedViewController as? UINavigationController,
               let subs = try? await container.subscriptionRepository.fetchAll(),
               let first = subs.first {
                let coordinator = SubscriptionDetailCoordinator(
                    navigationController: nav,
                    container: container,
                    subscription: first
                )
                previewCoordinators.append(coordinator)
                coordinator.start()
            }
        }

        if args.contains("-previewPaywall") {
            let coordinator = PaywallCoordinator(presentingController: tabBar, container: container)
            previewCoordinators.append(coordinator)
            coordinator.start()
        }

        if args.contains("-previewSettings") {
            tabBar.selectedIndex = 0
            if let nav = tabBar.selectedViewController as? UINavigationController {
                let coordinator = SettingsCoordinator(navigationController: nav, container: container)
                previewCoordinators.append(coordinator)
                coordinator.start()
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Flush a registration that was completed while offline.
        container?.retryPendingRegistrationIfNeeded()
        // Advance past-due renewal dates to the next billing cycle.
        container?.rollRenewalsForward()
        // Rebuild the next 60 days of renewal reminders.
        container?.resyncReminders()
        // Pick up a permission granted in iOS Settings while we were away.
        container?.refreshNotificationPermissionAfterForeground()
        // Keep the next recap notification scheduled.
        container?.refreshRecap()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        themeObservationTask?.cancel()
        localeObservationTask?.cancel()
        themeObservationTask = nil
        localeObservationTask = nil
    }

    private func observeTheme(themeManager: ThemeManaging, window: UIWindow) {
        themeObservationTask?.cancel()
        themeObservationTask = Task { [weak window, themeManager] in
            let stream = themeManager.observe()
            for await mode in stream {
                guard let window else { return }
                await MainActor.run {
                    window.overrideUserInterfaceStyle = mode.interfaceStyle
                }
            }
        }
    }

    private func observeLanguage(localizationManager: LocalizationManaging) {
        localeObservationTask?.cancel()
        var isFirstEmit = true
        localeObservationTask = Task { [weak self, localizationManager] in
            let stream = localizationManager.observe()
            for await _ in stream {
                if isFirstEmit {
                    isFirstEmit = false
                    continue
                }
                await MainActor.run {
                    self?.appCoordinator?.restart()
                }
            }
        }
    }
}
