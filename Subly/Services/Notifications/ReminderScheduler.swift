import Foundation
@preconcurrency import UserNotifications

/// Thin facade over `UNUserNotificationCenter` for renewal reminders. All
/// copy and timing decisions live in `ReminderContentBuilder`; this only
/// adds, removes and counts requests.
protocol ReminderScheduling: Sendable {
    /// Replaces every rebuilt reminder (lead / same-day / grouped, plus legacy
    /// identifiers) with `requests`. Snoozed one-offs are left alone.
    func replaceAll(with requests: [ReminderRequest]) async
    func add(_ request: ReminderRequest) async
    /// Drops the pending same-day reminder for one renewal (the **Keep** action).
    func removeSameDay(subscriptionID: UUID, renewalKey: String) async
    /// Pending requests that are not reminders; they share iOS's 64-slot cap.
    func unrelatedPendingCount() async -> Int
    /// Removes every pending request whose identifier starts with `prefix`.
    func removeAll(withPrefix prefix: String) async
}

struct LocalReminderScheduler: ReminderScheduling {

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func replaceAll(with requests: [ReminderRequest]) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let stale = pending.filter { id in
            (ReminderIdentifierPrefix.rebuilt + ReminderIdentifierPrefix.legacy).contains { id.hasPrefix($0) }
        }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for request in requests {
            await add(request)
        }
    }

    func add(_ request: ReminderRequest) async {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.categoryIdentifier = request.categoryIdentifier
        content.threadIdentifier = request.threadIdentifier
        content.userInfo = request.userInfo
        // Quiet hours: same time, no sound, `.passive` (no banner, no wake).
        // `.timeSensitive` needs the matching entitlement to break through
        // Focus; without it iOS quietly delivers the request as `.active`.
        switch request.deliveryStyle {
        case .silent:
            content.sound = nil
            content.interruptionLevel = .passive
        case .normal:
            content.sound = .default
            content.interruptionLevel = .active
        case .timeSensitive:
            content.sound = .default
            content.interruptionLevel = .timeSensitive
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let notification = UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
        _ = try? await center.add(notification)
    }

    func removeSameDay(subscriptionID: UUID, renewalKey: String) async {
        let identifier = "\(ReminderIdentifierPrefix.sameDay)\(subscriptionID.uuidString).\(renewalKey)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func unrelatedPendingCount() async -> Int {
        await center.pendingNotificationRequests()
            .filter { !ReminderIdentifierPrefix.isReminder($0.identifier) }
            .count
    }

    func removeAll(withPrefix prefix: String) async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// MARK: - Categories

/// The action lists iOS shows under a reminder. Registered once at launch;
/// `setNotificationCategories` replaces the whole set, so every category the
/// app uses must be listed here.
enum ReminderNotificationCategories {
    static func all() -> Set<UNNotificationCategory> {
        let keep = UNNotificationAction(
            identifier: ReminderAction.keep,
            title: Strings.Reminders.actionKeep,
            options: []
        )
        let remindTomorrow = UNNotificationAction(
            identifier: ReminderAction.remindTomorrow,
            title: Strings.Reminders.actionRemindTomorrow,
            options: []
        )
        let review = UNNotificationAction(
            identifier: ReminderAction.review,
            title: Strings.Reminders.actionReview,
            options: [.foreground]
        )
        return [
            UNNotificationCategory(
                identifier: ReminderCategory.standard,
                actions: [keep, remindTomorrow, review],
                intentIdentifiers: [],
                options: [.customDismissAction]
            ),
            UNNotificationCategory(
                identifier: ReminderCategory.imminent,
                actions: [keep, review],
                intentIdentifiers: [],
                options: [.customDismissAction]
            ),
            UNNotificationCategory(
                identifier: ReminderCategory.grouped,
                actions: [review],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: ReminderCategory.recap,
                actions: [],
                intentIdentifiers: [],
                options: []
            )
        ]
    }
}

// MARK: - Acknowledgements ("Keep subscription")

/// Renewals the user acknowledged from a notification, by subscription. The
/// builder skips the same-day reminder for an acknowledged renewal. Lives in
/// the App Group so a content extension can read it too.
final class ReminderAcknowledgementStore: @unchecked Sendable {

    private let defaults: UserDefaults
    private let key = "com.subly.reminders.acknowledged"

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard) {
        self.defaults = defaults
    }

    func acknowledge(subscriptionID: UUID, renewalKey: String) {
        var stored = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        stored[subscriptionID.uuidString] = renewalKey
        defaults.set(stored, forKey: key)
    }

    func acknowledged() -> [UUID: String] {
        let stored = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        var result: [UUID: String] = [:]
        for (idText, renewalKey) in stored {
            if let id = UUID(uuidString: idText) { result[id] = renewalKey }
        }
        return result
    }
}
