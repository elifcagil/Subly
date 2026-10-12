import UIKit

extension UIApplication {
    /// Opens this app's Notifications page in iOS Settings (iOS 16+), falling
    /// back to the app's general settings page.
    static func openNotificationSettings() {
        let url = URL(string: UIApplication.openNotificationSettingsURLString)
            ?? URL(string: UIApplication.openSettingsURLString)
        if let url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
