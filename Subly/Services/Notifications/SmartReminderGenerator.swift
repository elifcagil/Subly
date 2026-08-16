import Foundation

/// Emits Tier-2 ("Smart") notification payloads from a snapshot of the user's
/// active subscriptions. Roadmap §9.5.
///
/// Pure interface: takes value-type inputs, returns value-type outputs. Has
/// no access to a repository or the notification center. Future ML-backed
/// implementations plug in via `AppContainer` without feature-code changes.
protocol SmartReminderGenerating: Sendable {
    @MainActor
    func generate(
        subscriptions: [Subscription],
        relativeTo now: Date,
        calendar: Calendar
    ) -> [SmartReminderPayload]
}

/// Rule-based default. Three rules in order:
///
/// 1. **Weekly digest** — once a week, count renewals across the next 7 days
///    and fire one Smart payload Monday morning ("5 renewals this week").
/// 2. **Daily heavy** — when a single day in the next 7 days carries ≥ 3
///    renewals, fire a payload the previous morning ("Tomorrow is a heavy
///    day · 3 renewals").
/// 3. **New starts** — when one or more subscriptions have `startDate`
///    within the upcoming week (Phase 1 model carries start date), fire a
///    "Two new charges starting" payload the previous evening.
struct RuleBasedSmartReminderGenerator: SmartReminderGenerating {

    /// Hour-of-day to fire weekly + new-starts payloads.
    let weeklyHour: Int = 9
    /// Hour-of-day to fire daily-heavy payloads.
    let dailyHeavyHour: Int = 20

    /// Threshold at which a day counts as "heavy".
    let heavyThreshold: Int = 3

    @MainActor
    func generate(
        subscriptions: [Subscription],
        relativeTo now: Date,
        calendar: Calendar
    ) -> [SmartReminderPayload] {

        let active = subscriptions.filter { !$0.isArchived }
        guard !active.isEmpty else { return [] }

        var output: [SmartReminderPayload] = []

        if let weekly = generateWeeklyDigest(active: active, now: now, calendar: calendar) {
            output.append(weekly)
        }
        output.append(contentsOf: generateDailyHeavy(active: active, now: now, calendar: calendar))
        if let newStarts = generateNewStarts(active: active, now: now, calendar: calendar) {
            output.append(newStarts)
        }
        return output
    }

    // MARK: - Weekly

    private func generateWeeklyDigest(
        active: [Subscription],
        now: Date,
        calendar: Calendar
    ) -> SmartReminderPayload? {
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) else { return nil }
        let inWeek = active.filter { $0.nextRenewalDate >= now && $0.nextRenewalDate < weekEnd }
        guard inWeek.count >= 2 else { return nil }

        // Fire at the next Monday's `weeklyHour`. If today is Monday and
        // we're before that hour, fire today; otherwise the next Monday.
        guard let anchor = nextWeekdayMorning(weekday: 2 /* Monday */, hour: weeklyHour, from: now, calendar: calendar) else {
            return nil
        }

        let body = Strings.Notifications.smartWeekly(count: inWeek.count)
        return SmartReminderPayload(
            kind: .weekly,
            anchorDate: anchor,
            fireDate: anchor,
            title: Strings.Notifications.smartWeeklyTitle,
            body: body
        )
    }

    // MARK: - Daily heavy

    private func generateDailyHeavy(
        active: [Subscription],
        now: Date,
        calendar: Calendar
    ) -> [SmartReminderPayload] {
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) else { return [] }
        let inWeek = active.filter { $0.nextRenewalDate >= now && $0.nextRenewalDate < weekEnd }

        let grouped = Dictionary(grouping: inWeek) { calendar.startOfDay(for: $0.nextRenewalDate) }
        return grouped.compactMap { (day, items) -> SmartReminderPayload? in
            guard items.count >= heavyThreshold else { return nil }
            guard let evening = calendar.date(
                bySettingHour: dailyHeavyHour, minute: 0, second: 0,
                of: calendar.date(byAdding: .day, value: -1, to: day) ?? day
            ), evening > now else { return nil }

            let title = Strings.Notifications.smartHeavyTitle
            let body = Strings.Notifications.smartHeavyBody(count: items.count)
            return SmartReminderPayload(
                kind: .dailyHeavy,
                anchorDate: day,
                fireDate: evening,
                title: title,
                body: body
            )
        }
    }

    // MARK: - New starts

    private func generateNewStarts(
        active: [Subscription],
        now: Date,
        calendar: Calendar
    ) -> SmartReminderPayload? {
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) else { return nil }
        let newOnes = active.filter { $0.startDate >= now && $0.startDate < weekEnd }
        guard !newOnes.isEmpty else { return nil }

        // Anchor on the earliest new start; fire the previous evening.
        let earliest = newOnes.map(\.startDate).min() ?? now
        let anchorDay = calendar.startOfDay(for: earliest)
        guard let fireDate = calendar.date(
            bySettingHour: weeklyHour, minute: 0, second: 0,
            of: calendar.date(byAdding: .day, value: -1, to: anchorDay) ?? anchorDay
        ), fireDate > now else { return nil }

        return SmartReminderPayload(
            kind: .newStarts,
            anchorDate: anchorDay,
            fireDate: fireDate,
            title: Strings.Notifications.smartNewStartsTitle,
            body: Strings.Notifications.smartNewStartsBody(count: newOnes.count)
        )
    }

    // MARK: - Helpers

    private func nextWeekdayMorning(
        weekday: Int,
        hour: Int,
        from reference: Date,
        calendar: Calendar
    ) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0
        return calendar.nextDate(
            after: reference,
            matching: components,
            matchingPolicy: .nextTime
        )
    }
}
