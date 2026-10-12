import UIKit

@MainActor
final class AppCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let container: AppContainer
    private let onboardingFlag = "com.subly.onboarding.completed"

    init(window: UIWindow, container: AppContainer) {
        self.window = window
        self.container = container
    }

    func start() {
        showSplash()
    }

    func restart() {
        childCoordinators.removeAll()
        window.rootViewController = nil
        // After a restart (e.g. language change) the splash has already played
        // and replaying it would feel like a relaunch. Route straight to the
        // next surface.
        advanceFromSplash()
    }

    private func showSplash() {
        let coordinator = SplashCoordinator(window: window)
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
            self.advanceFromSplash()
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func advanceFromSplash() {
        // Cross-dissolve the window root so the splash fades into the next
        // surface smoothly. Without this wrap, the rootViewController swap
        // would be an instant cut — jarring after the polished splash motion.
        UIView.transition(
            with: window,
            duration: 0.4,
            options: [.transitionCrossDissolve, .allowAnimatedContent],
            animations: { [weak self] in
                guard let self else { return }
                if !self.container.registrationService.isRegistered {
                    // One-time device registration (00B → 00C). Returning
                    // users never see these screens again.
                    self.showRegistration()
                } else if UserDefaults.standard.bool(forKey: self.onboardingFlag) {
                    self.showMainShell()
                } else {
                    self.showOnboarding()
                }
            },
            completion: nil
        )
    }

    private func showRegistration() {
        let coordinator = RegistrationCoordinator(window: window, container: container)
        coordinator.onFinished = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
            // Fresh install: this version's What's New is "seen" — only
            // updates get the story.
            self.container.whatsNewStore.markSeen(version: AppVersion.current)
            // Resume the normal route (onboarding for first-timers).
            UIView.transition(
                with: self.window,
                duration: 0.4,
                options: [.transitionCrossDissolve, .allowAnimatedContent],
                animations: {
                    if UserDefaults.standard.bool(forKey: self.onboardingFlag) {
                        self.showMainShell()
                    } else {
                        self.showOnboarding()
                    }
                }
            )
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func showOnboarding() {
        let coordinator = OnboardingCoordinator(window: window, container: container)
        coordinator.onFinished = { [weak self, weak coordinator] outcome in
            guard let self, let coordinator else { return }
            UserDefaults.standard.set(true, forKey: self.onboardingFlag)
            self.removeChild(coordinator)
            self.showMainShell(startingAddFlow: outcome == .addFirst)
        }
        addChild(coordinator)
        coordinator.start()
    }

    private func showMainShell(startingAddFlow: Bool = false) {
        let coordinator = TabBarCoordinator(window: window, container: container)
        addChild(coordinator)
        coordinator.start()
        if presentWhatsNewIfDue(over: coordinator) {
            // The story covers the shell; the usual entry prompts follow once
            // it is dismissed (see `presentWhatsNewIfDue`).
            return
        }
        if startingAddFlow {
            // Give the shell a beat to settle before presenting the sheet.
            // The notification prompt follows once that sheet closes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak coordinator] in
                coordinator?.presentAddFlow()
            }
        } else {
            // First entry (or still undetermined): ask for notification
            // permission once the dashboard has settled.
            coordinator.promptForNotificationPermissionIfNeeded(after: 0.8)
        }
    }

    /// First launch after an update → the What's New story opens over the
    /// shell before the Dashboard is seen (no tap needed). Returns `false`
    /// when nothing is due.
    @discardableResult
    private func presentWhatsNewIfDue(over shell: TabBarCoordinator) -> Bool {
        guard let payload = WhatsNewCoordinator.currentPayload(),
              WhatsNewGate.shouldShow(
                currentVersion: AppVersion.current,
                lastSeenVersion: container.whatsNewStore.lastSeenVersion,
                hasPayload: true
              ),
              let host = window.rootViewController else { return false }
        let coordinator = WhatsNewCoordinator(presentingController: host, container: container, payload: payload)
        coordinator.onFinished = { [weak self, weak coordinator, weak shell] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
            shell?.promptForNotificationPermissionIfNeeded(after: 0.5)
        }
        addChild(coordinator)
        coordinator.start(animated: false)
        return true
    }
}
