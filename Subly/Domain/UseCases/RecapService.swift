import Foundation

/// Pure recap builder (handoff: `CLAUDE_CODE_PROMPT_RECAP.md`).
///
/// - Period total = projected charges inside the period, in one currency.
///   Amounts are never converted: the recap uses the currency with the most
///   subscriptions active in the period (ties → preferred currency).
/// - The first recap (index 1) needs at least one subscription that existed
///   for the whole period; otherwise `nil` (skip and wait).
/// - Price increases need price history, which v1 does not store → always
///   empty, so that card never appears.
struct RecapService: Sendable {

    private let calendar: Calendar
    private let projector: PaymentProjector

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.projector = PaymentProjector(calendar: calendar)
    }

    func recap(
        index: Int,
        period: DateInterval,
        previousPeriod: DateInterval?,
        subscriptions: [Subscription],
        preferredCurrencyCode: String,
        now: Date
    ) -> Recap? {
        let inPeriod = subscriptions.filter {
            !$0.isArchived && calendar.startOfDay(for: $0.startDate) < period.end
        }
        guard !inPeriod.isEmpty else { return nil }

        if index == 1 {
            let wholePeriod = inPeriod.contains { calendar.startOfDay(for: $0.startDate) <= period.start }
            guard wholePeriod else { return nil }
        }

        let currency = dominantCurrency(in: inPeriod, preferred: preferredCurrencyCode)
        let candidates = inPeriod.filter { $0.currencyCode == currency }
        let paid = candidates.map { ($0, projector.amountPaid(by: $0, in: period)) }.filter { $0.1 > 0 }
        let total = paid.reduce(Decimal(0)) { $0 + $1.1 }
        guard total > 0 else { return nil }

        let days = max(1, calendar.dateComponents([.day], from: period.start, to: period.end).day ?? 90)
        let perDay = total / Decimal(days)

        let bars = monthBars(for: candidates, in: period)

        let comparison: Recap.Comparison? = previousPeriod.map { previous in
            let previousTotal = candidates.reduce(Decimal(0)) { $0 + projector.amountPaid(by: $1, in: previous) }
            return Recap.Comparison(delta: total - previousTotal)
        }

        let topItem: Recap.TopItem? = paid.max { $0.1 < $1.1 }.map { sub, amount in
            Recap.TopItem(
                subscription: sub,
                paid: amount,
                share: NSDecimalNumber(decimal: amount / total).doubleValue
            )
        }

        let longest: Recap.LongestRunning? = inPeriod
            .filter { $0.currencyCode == currency }
            .min { $0.startDate < $1.startDate }
            .map { sub in
                let months = max(1, calendar.dateComponents([.month], from: calendar.startOfDay(for: sub.startDate), to: now).month ?? 0)
                return Recap.LongestRunning(
                    subscription: sub,
                    months: months,
                    totalPaid: projector.amountPaidToDate(by: sub, now: now)
                )
            }

        return Recap(
            index: index,
            period: period,
            currencyCode: currency,
            total: total,
            subscriptionCount: paid.count,
            perDay: perDay,
            monthBars: bars,
            comparison: comparison,
            topItem: topItem,
            priceIncreases: [],
            longestRunning: longest
        )
    }

    // MARK: - Helpers

    private func dominantCurrency(in subscriptions: [Subscription], preferred: String) -> String {
        let counts = Dictionary(grouping: subscriptions, by: \.currencyCode).mapValues(\.count)
        guard let best = counts.max(by: { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            // Prefer the user's display currency on a tie.
            return (lhs.key == preferred ? 1 : 0) < (rhs.key == preferred ? 1 : 0)
        }) else { return preferred }
        return best.key
    }

    /// One bar per month-slice of the period (3 for a 3-month period).
    private func monthBars(for subscriptions: [Subscription], in period: DateInterval) -> [Recap.MonthBar] {
        var bars: [Recap.MonthBar] = []
        var sliceStart = period.start
        var steps = 0
        while sliceStart < period.end && steps < 12 {
            let sliceEnd = min(period.end, calendar.date(byAdding: .month, value: 1, to: sliceStart) ?? period.end)
            let slice = DateInterval(start: sliceStart, end: sliceEnd)
            let total = subscriptions.reduce(Decimal(0)) { $0 + projector.amountPaid(by: $1, in: slice) }
            bars.append(Recap.MonthBar(monthStart: sliceStart, total: total))
            sliceStart = sliceEnd
            steps += 1
        }
        return bars
    }
}
