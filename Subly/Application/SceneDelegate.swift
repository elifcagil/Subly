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
                coordinator.start()
                await self.presentPreviewIfRequested(container: container)
            }
        } else {
            coordinator.start()
        }
        window.makeKeyAndVisible()
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
