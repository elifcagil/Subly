import IQKeyboardManagerSwift
import IQKeyboardToolbarManager
import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    private let notificationDelegate = NotificationCenterDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationManager().registerActions()
        configureKeyboardManager()
        return true
    }

    /// Keyboard handling app-wide: content scrolls clear of the keyboard, a
    /// tap outside dismisses it, and every input (the decimal pad included,
    /// which has no return key of its own) gets a toolbar with a localized
    /// Done button.
    private func configureKeyboardManager() {
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true
        IQKeyboardToolbarManager.shared.isEnabled = true
        IQKeyboardToolbarManager.shared.toolbarConfiguration.useTextInputViewTintColor = true
        IQKeyboardToolbarManager.shared.toolbarConfiguration.placeholderConfiguration.showPlaceholder = false
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == SublyNotificationCategory.snoozeAction {
            let identifier = response.notification.request.identifier
            Task {
                try? await NotificationManager().snooze(identifier: identifier, by: 24)
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
}
