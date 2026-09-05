import Foundation
import WidgetKit

/// Keeps every active subscription "in the loop" until the user archives or
/// deletes it: renewal dates that slipped into the past are advanced to the
/// first cycle date on or after today (docs/YENILEME_DONGUSU_PLANI.md).
///
/// Runs on launch/foregrounding (`sceneDidBecomeActive`) and when the calendar
/// day changes while the app is open. Idempotent — a second pass right after
/// the first finds nothing to change — so overlapping triggers are harmless;
/// `isRunning` merely skips the redundant work.
///
/// A subscription renewing *today* is deliberately left untouched until the
/// day ends, so "renews today" stays visible all day.
@MainActor
final class RenewalRolloverService {

    private let repository: SubscriptionRepository
    private let notificationScheduler: NotificationScheduling
    private let preferences: SettingsPreferencesManaging
    private let dateProvider: DateProviding
    private var isRunning = false
    private var dayChangeObserver: NSObjectProtocol?

    init(
        repository: SubscriptionRepository,
        notificationScheduler: NotificationScheduling,
        preferences: SettingsPreferencesManaging,
        dateProvider: DateProviding
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
        self.preferences = preferences
        self.dateProvider = dateProvider
    }

    deinit {
        if let dayChangeObserver {
            NotificationCenter.default.removeObserver(dayChangeObserver)
        }
    }

    /// Rolls stale renewals forward if the calendar day flips while the app
    /// stays open (e.g. left on screen over midnight).
    func startObservingDayChanges() {
        guard dayChangeObserver == nil else { return }
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                await self?.rollForwardExpired()
            }
        }
    }

    /// Advances every active subscription whose `nextRenewalDate` is before
    /// the start of today, reschedules its reminders, and refreshes widgets.
    /// Returns the subscriptions that were advanced.
    @discardableResult
    func rollForwardExpired() async -> [Subscription] {
        guard !isRunning else { return [] }
        isRunning = true
        defer { isRunning = false }

        guard let all = try? await repository.fetchAll() else { return [] }
        let calendar = dateProvider.calendar
        let startOfToday = calendar.startOfDay(for: dateProvider.now)
        let calculator = RenewalDateCalculator(calendar: calendar)

        var rolled: [Subscription] = []
        for subscription in all
        where !subscription.isArchived && subscription.nextRenewalDate < startOfToday {
            var updated = subscription
            updated.nextRenewalDate = calculator.upcomingRenewalDate(
                from: subscription.nextRenewalDate,
                cycle: subscription.billingCycle,
                relativeTo: startOfToday
            )
            do {
                try await repository.save(updated)
                rolled.append(updated)
            } catch {
                // Leave this one stale; the next pass retries it.
                continue
            }
        }

        guard !rolled.isEmpty else { return [] }

        if preferences.current().remindersEnabled {
            for subscription in rolled where !subscription.reminderLeadDays.isEmpty {
                // `schedule` cancels the subscription's stale pending
                // notifications before adding the new cycle's.
                try? await notificationScheduler.schedule(
                    for: subscription,
                    leadDays: subscription.reminderLeadDays
                )
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return rolled
    }
}
