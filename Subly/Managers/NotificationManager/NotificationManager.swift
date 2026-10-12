import Foundation
@preconcurrency import UserNotifications

protocol NotificationScheduling: Sendable {

    // MARK: Phase 1 — renewal scheduling (unchanged surface)

    func requestAuthorization() async throws -> Bool
    /// Registers the reminder action categories (once, at launch). Per-
    /// subscription renewal reminders themselves are built and scheduled by
    /// `ReminderSyncService` + `LocalReminderScheduler`.
    func registerActions()

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
    static let smart = "subly.smart"
    static let awareness = "subly.awareness"
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

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// `setNotificationCategories` replaces the whole set, so every category
    /// the app uses is registered here in one go.
    func registerActions() {
        center.setNotificationCategories(ReminderNotificationCategories.all())
    }

    func requestAuthorization() async throws -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            throw NotificationError.permissionDenied
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
        //    Renewal reminders are left untouched — `ReminderSyncService`
        //    owns them.
        let pending = await center.pendingNotificationRequests()
        let staleSmart = pending.filter {
            $0.identifier.hasPrefix(NotificationIdentifierPrefix.smart)
            || $0.identifier.hasPrefix(NotificationIdentifierPrefix.awareness)
        }
        center.removePendingNotificationRequests(
            withIdentifiers: staleSmart.map(\.identifier)
        )

        // 2. Apply policy: coalesce same-day, throttle to N/day, dedupe 24h.
        let pendingRenewals = pending.filter { request in
            ReminderIdentifierPrefix.rebuilt.contains { request.identifier.hasPrefix($0) }
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
