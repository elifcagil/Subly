import UIKit

extension UIViewController {

    /// Delete confirmation shared by the list and the detail screen.
    ///
    /// When the service has a known website, the prompt offers to open it so
    /// the user can cancel there too: **Yes** deletes the subscription from
    /// Subly and opens the site; **No** leaves everything as is. Unknown
    /// services fall back to a plain Delete / Cancel prompt.
    func presentDeleteSubscriptionPrompt(
        name: String,
        haptics: HapticsService,
        onDelete: @escaping () -> Void
    ) {
        let alert = UIAlertController(
            title: String(format: Strings.DeleteFlow.titleFormat, name),
            message: nil,
            preferredStyle: .alert
        )

        if let site = ServiceWebsiteDirectory.url(forServiceNamed: name) {
            alert.message = String(format: Strings.DeleteFlow.visitSiteMessageFormat, name)
            alert.addAction(UIAlertAction(title: Strings.DeleteFlow.no, style: .cancel))
            alert.addAction(UIAlertAction(title: Strings.DeleteFlow.yesOpenSite, style: .destructive) { _ in
                haptics.play(.warning)
                onDelete()
                UIApplication.shared.open(site)
            })
        } else {
            alert.message = Strings.DeleteFlow.plainMessage
            alert.addAction(UIAlertAction(title: Strings.Common.cancel, style: .cancel))
            alert.addAction(UIAlertAction(title: Strings.Common.delete, style: .destructive) { _ in
                haptics.play(.warning)
                onDelete()
            })
        }
        present(alert, animated: true)
    }
}
