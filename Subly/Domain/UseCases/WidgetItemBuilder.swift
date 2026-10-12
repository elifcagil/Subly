import Foundation

/// One subscription as the widget shows it. Pure data, built from the shared
/// store by `WidgetItemBuilder`; the widget only renders it.
struct WidgetItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let tile: BrandTile
    let amount: Decimal
    let currencyCode: String
    let renewalDate: Date
    let progress: RenewalProgressCalculator.Progress

    var daysLeft: Int { progress.daysLeft }
}

/// Turns active subscriptions into widget items: renewal dates that slipped
/// into the past (app unopened) are projected to the next cycle, items are
/// ordered soonest first, and pinned IDs — when given — are kept in the
/// user's order.
struct WidgetItemBuilder: Sendable {

    private let calendar: Calendar
    private let renewalCalculator: RenewalDateCalculator
    private let progressCalculator: RenewalProgressCalculator

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.renewalCalculator = RenewalDateCalculator(calendar: calendar)
        self.progressCalculator = RenewalProgressCalculator(calendar: calendar)
    }

    func items(
        from subscriptions: [Subscription],
        pinned: [UUID] = [],
        limit: Int,
        on date: Date
    ) -> [WidgetItem] {
        let today = calendar.startOfDay(for: date)
        let active = subscriptions.filter { !$0.isArchived }

        let candidates: [Subscription]
        if pinned.isEmpty {
            candidates = active
        } else {
            let byID = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
            candidates = pinned.compactMap { byID[$0] }
        }

        let items = candidates.map { sub -> WidgetItem in
            var renewal = sub.nextRenewalDate
            if renewal < today {
                renewal = renewalCalculator.upcomingRenewalDate(from: renewal, cycle: sub.billingCycle, relativeTo: today)
            }
            return WidgetItem(
                id: sub.id,
                name: sub.name,
                tile: BrandPalette.tile(forName: sub.name),
                amount: sub.amount,
                currencyCode: sub.currencyCode,
                renewalDate: renewal,
                progress: progressCalculator.progress(renewalDate: renewal, cycle: sub.billingCycle, on: today)
            )
        }

        let ordered = pinned.isEmpty
            ? items.sorted { ($0.renewalDate, $0.name) < ($1.renewalDate, $1.name) }
            : items
        return Array(ordered.prefix(max(0, limit)))
    }

    /// Sum of the given items' amounts due within the next 7 days, per
    /// currency (never mixed), sorted by currency code.
    func weeklyTotals(of items: [WidgetItem], on date: Date) -> [(currencyCode: String, total: Decimal)] {
        let today = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }
        let inWeek = items.filter { $0.renewalDate >= today && $0.renewalDate < end }
        return Dictionary(grouping: inWeek, by: \.currencyCode)
            .map { code, group in (code, group.reduce(Decimal(0)) { $0 + $1.amount }) }
            .sorted { $0.0 < $1.0 }
    }
}
