import Foundation
@preconcurrency import UserNotifications

protocol NotificationScheduling: Sendable {

    // MARK: Phase 1 — renewal scheduling (unchanged surface)

    func requestAuthorization() async throws -> Bool
    func schedule(for subscription: Subscription, leadDays: [Int]) async throws
    func cancel(for subscriptionID: UUID) async
    func pendingIdentifiers(for subscriptionID: UUID) async -> [String]
    func registerActions()
    func snooze(identifier: String, by hours: Int) async throws

    // MARK: Phase 9 — smart + awareness + reconcile

    /// Schedule a batch of `Smart Reminder` notifications about groups of
    /// subscriptions (e.g. "5 renewing this week").
    func scheduleSmart(_ payloads: [SmartReminderPayload]) async

    /// Schedule a batch of `Financial Awareness` notifications about
    /// spending pressure over time.
    func scheduleAwareness(_ payloads: [AwarenessPayload]) async

    /// Re-run coalesce / throttle / dedupe over the *full* pending set.
    /// Called on app launch and after any data change (subscription added,
    /// archived, currency changed, defaults updated). Always operates on the
    /// complete state, so policy is enforced consistently rather than
    /// incrementally.
    ///
    /// - Parameters:
    ///   - smart: payloads emitted by `SmartReminderGenerating`.
    ///   - awareness: payloads emitted by `AwarenessGenerating`.
    func reconcileAll(smart: [SmartReminderPayload], awareness: [AwarenessPayload]) async
}

enum SublyNotificationCategory {
    static let renewal = "subly.renewal"
    static let smart = "subly.smart"
    static let awareness = "subly.awareness"
    static let snoozeAction = "subly.snooze"
}

/// Identifier prefixes used by Phase 9's three-tier notification system.
/// Surgical cancellation depends on these — cancelling all `smart.*` must
/// never touch `renewal.*`.
enum NotificationIdentifierPrefix {
    static let renewal = "renewal."
    static let smart = "smart."
    static let awareness = "awareness."
    static let coalesced = "coalesced."
}

struct NotificationManager: NotificationScheduling {

    private let center: UNUserNotificationCenter
    private let currencyFormatter: CurrencyFormatting

    init(
        center: UNUserNotificationCenter = .current(),
        currencyFormatter: CurrencyFormatting = CurrencyFormatter()
    ) {
        self.center = center
        self.currencyFormatter = currencyFormatter
    }

    func registerActions() {
        let snooze = UNNotificationAction(
            identifier: SublyNotificationCategory.snoozeAction,
            title: "Snooze 1 day",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: SublyNotificationCategory.renewal,
            actions: [snooze],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async throws -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            throw NotificationError.permissionDenied
        }
    }

    func schedule(for subscription: Subscription, leadDays: [Int]) async throws {
        await cancel(for: subscription.id)
        let calendar = Calendar.current

        for offset in leadDays {
            guard let fireDate = calendar.date(byAdding: .day, value: -offset, to: subscription.nextRenewalDate),
                  fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            // v5 screen 11: specific title ("Netflix renews tomorrow — $15.49"),
            // calm actionable body — helpful, never nagging.
            content.title = renewalTitle(for: subscription, offset: offset)
            content.body = Strings.Notifications.renewalBody
            content.sound = .default
            content.categoryIdentifier = SublyNotificationCategory.renewal
            content.userInfo = ["subscriptionID": subscription.id.uuidString, "leadDay": offset]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = makeIdentifier(subscriptionID: subscription.id, leadDay: offset)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                throw NotificationError.schedulingFailed
            }
        }
    }

    func cancel(for subscriptionID: UUID) async {
        let identifiers = await pendingIdentifiers(for: subscriptionID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingIdentifiers(for subscriptionID: UUID) async -> [String] {
        let pending = await center.pendingNotificationRequests()
        // Match both the new Phase 9 prefix and the legacy Phase 1 prefix —
        // the latter exists in installs upgraded from before Phase 9.
        let newPrefix = "\(NotificationIdentifierPrefix.renewal)\(subscriptionID.uuidString)."
        let legacyPrefix = "subscription.\(subscriptionID.uuidString)."
        return pending.map(\.identifier).filter {
            $0.hasPrefix(newPrefix) || $0.hasPrefix(legacyPrefix)
        }
    }

    func snooze(identifier: String, by hours: Int) async throws {
        let pending = await center.pendingNotificationRequests()
        guard let original = pending.first(where: { $0.identifier == identifier }) else { return }

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let snoozeDate = Date().addingTimeInterval(TimeInterval(hours * 3600))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: snoozeDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(identifier).snoozed",
            content: original.content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed
        }
    }

    private func makeIdentifier(subscriptionID: UUID, leadDay: Int) -> String {
        // Phase 9 prefix — `renewal.{subID}.{leadDays}`
        "\(NotificationIdentifierPrefix.renewal)\(subscriptionID.uuidString).\(leadDay)"
    }

    private func renewalTitle(for subscription: Subscription, offset: Int) -> String {
        let amount = currencyFormatter.string(
            from: subscription.amount,
            currencyCode: subscription.currencyCode
        )
        switch offset {
        case 0: return Strings.Notifications.renewalTitleToday(name: subscription.name, amount: amount)
        case 1: return Strings.Notifications.renewalTitleTomorrow(name: subscription.name, amount: amount)
        default: return Strings.Notifications.renewalTitleInDays(name: subscription.name, days: offset, amount: amount)
        }
    }

    // MARK: - Phase 9 — smart + awareness + reconcile

    func scheduleSmart(_ payloads: [SmartReminderPayload]) async {
        for payload in payloads {
            await addRequest(
                identifier: payload.identifier,
                title: payload.title,
                body: payload.body,
                fireDate: payload.fireDate,
                categoryIdentifier: SublyNotificationCategory.smart
            )
        }
    }

    func scheduleAwareness(_ payloads: [AwarenessPayload]) async {
        for payload in payloads {
            await addRequest(
                identifier: payload.identifier,
                title: payload.title,
                body: payload.body,
                fireDate: payload.fireDate,
                categoryIdentifier: SublyNotificationCategory.awareness
            )
        }
    }

    /// Phase 9 reconcile — see §9.6 for the rule order. Operates on the *full*
    /// pending set so policy is enforced consistently.
    func reconcileAll(smart: [SmartReminderPayload], awareness: [AwarenessPayload]) async {
        let policy = NotificationSchedulingPolicy()

        // 1. Read all currently pending requests for awareness/smart tiers.
        //    Renewal-tier requests are left untouched — they are managed
        //    individually by AddEdit save and SubscriptionDetail delete.
        let pending = await center.pendingNotificationRequests()
        let staleSmart = pending.filter {
            $0.identifier.hasPrefix(NotificationIdentifierPrefix.smart)
            || $0.identifier.hasPrefix(NotificationIdentifierPrefix.awareness)
        }
        center.removePendingNotificationRequests(
            withIdentifiers: staleSmart.map(\.identifier)
        )

        // 2. Apply policy: coalesce same-day, throttle to N/day, dedupe 24h.
        let pendingRenewals = pending.filter {
            $0.identifier.hasPrefix(NotificationIdentifierPrefix.renewal)
        }
        let plan = policy.plan(
            renewals: pendingRenewals,
            smart: smart,
            awareness: awareness
        )

        // 3. Schedule the planned set.
        await scheduleSmart(plan.smartToSchedule)
        await scheduleAwareness(plan.awarenessToSchedule)
    }

    /// Internal helper for adding a UNNotificationRequest without exposing the
    /// raw center to callers.
    private func addRequest(
        identifier: String,
        title: String,
        body: String,
        fireDate: Date,
        categoryIdentifier: String
    ) async {
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        _ = try? await center.add(request)
    }
}
