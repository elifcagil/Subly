import Foundation
@preconcurrency import UserNotifications

/// Routes taps and action buttons on reminder notifications.
///
/// - **Keep subscription** → acknowledges the renewal (no same-day reminder)
/// - **Remind me tomorrow** → one-off reminder tomorrow at delivery time
/// - **Review in Subly** / tapping the banner → opens Subscription Detail
///
/// Opening the detail screen goes through `DeepLinkRouter`, which parks the
/// request when the tap launches the app before the main shell exists.
@MainActor
final class NotificationActionHandler {

    static let shared = NotificationActionHandler()

    private let router: DeepLinkRouter
    private let scheduler: ReminderScheduling
    private let builder: ReminderContentBuilder
    private let acknowledgements: ReminderAcknowledgementStore

    init(
        router: DeepLinkRouter = .shared,
        scheduler: ReminderScheduling = LocalReminderScheduler(),
        builder: ReminderContentBuilder = ReminderContentBuilder(),
        acknowledgements: ReminderAcknowledgementStore = ReminderAcknowledgementStore()
    ) {
        self.router = router
        self.scheduler = scheduler
        self.builder = builder
        self.acknowledgements = acknowledgements
    }

    func handle(_ response: UNNotificationResponse) async {
        let raw = response.notification.request.content.userInfo
        var userInfo: [String: String] = [:]
        for (key, value) in raw {
            if let key = key as? String, let value = value as? String { userInfo[key] = value }
        }

        if response.notification.request.content.categoryIdentifier == ReminderCategory.recap {
            let index = userInfo["recapIndex"].flatMap { Int($0) }
            router.open(.recap(index: index))
            return
        }

        switch response.actionIdentifier {
        case ReminderAction.keep:
            await keep(userInfo)
        case ReminderAction.remindTomorrow:
            await remindTomorrow(userInfo)
        case ReminderAction.review, UNNotificationDefaultActionIdentifier:
            openSubscription(from: userInfo)
        default:
            break
        }
    }

    // MARK: - Actions

    private func keep(_ userInfo: [String: String]) async {
        guard let id = userInfo[ReminderUserInfoKey.subscriptionID].flatMap(UUID.init(uuidString:)),
              let renewalKey = userInfo[ReminderUserInfoKey.renewalDate] else { return }
        acknowledgements.acknowledge(subscriptionID: id, renewalKey: renewalKey)
        await scheduler.removeSameDay(subscriptionID: id, renewalKey: renewalKey)
    }

    private func remindTomorrow(_ userInfo: [String: String]) async {
        guard let request = builder.snoozedRequest(from: userInfo, quietHours: QuietHoursStore().current(), now: Date()) else { return }
        await scheduler.add(request)
    }

    private func openSubscription(from userInfo: [String: String]) {
        // A grouped reminder carries several IDs; open the first one.
        let idText = userInfo[ReminderUserInfoKey.subscriptionID]
            ?? userInfo[ReminderUserInfoKey.subscriptionIDs]?.split(separator: ",").first.map(String.init)
        guard let id = idText.flatMap(UUID.init(uuidString:)) else { return }
        router.open(.subscription(id))
    }
}
