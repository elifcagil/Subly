import Foundation
@preconcurrency import UserNotifications

/// Policy layer between generators and the raw UN-center facade.
///
/// Roadmap §9.6. Applies three rules in this exact order on every reconcile:
///
/// 1. **Coalesce** same-day Renewal Notifications. Three reminders due on
///    the same calendar day collapse into one Smart-tier message
///    ("3 renewals today · ₺X"). Renewal originals stay scheduled — the
///    coalesced summary is *additional*, fired earlier in the day. (We
///    don't drop the originals because users opted into per-subscription
///    reminders explicitly in Phase 6.6.)
///
/// 2. **Throttle** per-day. A hard ceiling of `dailyCeiling` notifications
///    per local calendar day (default 3). When exceeded, the lowest-priority
///    Smart/Awareness messages are dropped silently. Renewal-tier
///    notifications are never dropped — they're a user contract.
///
/// 3. **Dedupe** content. Identical title+body hashes within a 24-hour
///    window collapse to one. Stable identifiers (same kind, same day)
///    already prevent most duplicates; this rule catches the rest.
///
/// The policy is **pure**: it doesn't touch `UNUserNotificationCenter`. It
/// reads pending requests as input and emits a `Plan` for the manager to
/// execute. This keeps the policy testable and the manager thin.
struct NotificationSchedulingPolicy: Sendable {

    /// Maximum notifications scheduled per local calendar day (Smart +
    /// Awareness combined). Renewal-tier sits outside this cap.
    let dailyCeiling: Int

    /// Time-of-day for the coalesced summary. Default 09:00 local — early
    /// enough that the user sees it before any per-subscription renewal
    /// notification fires.
    let coalescedFireHour: Int

    private let calendar: Calendar

    init(
        dailyCeiling: Int = 3,
        coalescedFireHour: Int = 9,
        calendar: Calendar = .current
    ) {
        self.dailyCeiling = dailyCeiling
        self.coalescedFireHour = coalescedFireHour
        self.calendar = calendar
    }

    // MARK: - Plan

    struct Plan: Sendable {
        let smartToSchedule: [SmartReminderPayload]
        let awarenessToSchedule: [AwarenessPayload]
    }

    func plan(
        renewals: [UNNotificationRequest],
        smart: [SmartReminderPayload],
        awareness: [AwarenessPayload]
    ) -> Plan {

        // Phase 1 of this method is intentionally tiny — most of the work
        // happens in the per-rule helpers below, and each is independently
        // legible. The order matters: coalesce produces extra Smart
        // payloads, throttle then applies the ceiling, dedupe runs last.

        var smartAfterCoalesce = smart
        let coalesced = coalesceSameDayRenewals(renewals)
        smartAfterCoalesce.append(contentsOf: coalesced)

        let throttled = throttle(smart: smartAfterCoalesce, awareness: awareness)
        let deduped = dedupe(smart: throttled.smart, awareness: throttled.awareness)

        return Plan(
            smartToSchedule: deduped.smart,
            awarenessToSchedule: deduped.awareness
        )
    }

    // MARK: - Coalesce

    /// Groups pending renewal requests by calendar day; emits one Smart
    /// payload summary for any day with ≥ 2 renewals.
    private func coalesceSameDayRenewals(_ renewals: [UNNotificationRequest]) -> [SmartReminderPayload] {
        let withDate: [(UNNotificationRequest, Date)] = renewals.compactMap { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let date = trigger.nextTriggerDate() else { return nil }
            return (request, date)
        }
        let grouped = Dictionary(grouping: withDate, by: { calendar.startOfDay(for: $0.1) })

        return grouped.compactMap { (day, items) -> SmartReminderPayload? in
            guard items.count >= 2 else { return nil }
            let count = items.count
            guard let fireDate = calendar.date(
                bySettingHour: coalescedFireHour, minute: 0, second: 0, of: day
            ), fireDate > Date() else { return nil }

            // Copy is deliberately bland; the per-locale `Strings` layer
            // would normally wrap this, but since the policy is *pure* and
            // does not depend on the localization bundle, we use a default
            // English template here. The reconcile call site can override
            // by passing localized payloads from the generators.
            let title = "Today's renewals"
            let body = "\(count) subscriptions renew today."
            return SmartReminderPayload(
                kind: .dailyHeavy,
                anchorDate: day,
                fireDate: fireDate,
                title: title,
                body: body
            )
        }
    }

    // MARK: - Throttle

    private struct ThrottleResult {
        let smart: [SmartReminderPayload]
        let awareness: [AwarenessPayload]
    }

    /// Drops the lowest-priority items per day until the ceiling is met.
    /// Renewal-tier requests sit outside this cap so they are *not* counted —
    /// the ceiling is for Smart + Awareness only.
    private func throttle(
        smart: [SmartReminderPayload],
        awareness: [AwarenessPayload]
    ) -> ThrottleResult {

        struct Item {
            let day: Date
            let priority: NotificationPriority
            let fireDate: Date
            let smart: SmartReminderPayload?
            let awareness: AwarenessPayload?
        }

        var items: [Item] = []
        for payload in smart {
            items.append(Item(
                day: calendar.startOfDay(for: payload.fireDate),
                priority: payload.priority,
                fireDate: payload.fireDate,
                smart: payload,
                awareness: nil
            ))
        }
        for payload in awareness {
            items.append(Item(
                day: calendar.startOfDay(for: payload.fireDate),
                priority: payload.priority,
                fireDate: payload.fireDate,
                smart: nil,
                awareness: payload
            ))
        }

        // Group by day; within each day, keep the highest-priority items
        // first; truncate at the ceiling.
        let grouped = Dictionary(grouping: items, by: \.day)
        var kept: [Item] = []
        for (_, dayItems) in grouped {
            let sorted = dayItems.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.fireDate < rhs.fireDate
            }
            kept.append(contentsOf: sorted.prefix(dailyCeiling))
        }

        return ThrottleResult(
            smart: kept.compactMap(\.smart),
            awareness: kept.compactMap(\.awareness)
        )
    }

    // MARK: - Dedupe

    private struct DedupeResult {
        let smart: [SmartReminderPayload]
        let awareness: [AwarenessPayload]
    }

    /// Collapses identical (title + body + day) hashes within a rolling
    /// 24-hour window. Stable identifiers already prevent most duplicates;
    /// this catches the rest (e.g. two awareness payloads with different
    /// kinds but the same copy because the rule engine produced identical
    /// output).
    private func dedupe(
        smart: [SmartReminderPayload],
        awareness: [AwarenessPayload]
    ) -> DedupeResult {
        var seen: Set<String> = []
        var keptSmart: [SmartReminderPayload] = []
        var keptAwareness: [AwarenessPayload] = []

        for payload in smart.sorted(by: { $0.fireDate < $1.fireDate }) {
            let key = "\(payload.title)|\(payload.body)|\(NotificationIdentifierFormatter.dayKey(for: payload.fireDate, calendar: calendar))"
            if seen.insert(key).inserted {
                keptSmart.append(payload)
            }
        }
        for payload in awareness.sorted(by: { $0.fireDate < $1.fireDate }) {
            let key = "\(payload.title)|\(payload.body)|\(NotificationIdentifierFormatter.dayKey(for: payload.fireDate, calendar: calendar))"
            if seen.insert(key).inserted {
                keptAwareness.append(payload)
            }
        }

        return DedupeResult(smart: keptSmart, awareness: keptAwareness)
    }
}
