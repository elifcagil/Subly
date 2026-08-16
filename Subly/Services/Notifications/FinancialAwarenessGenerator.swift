import Foundation

/// Emits Tier-3 ("Financial Awareness") notification payloads. Roadmap §9.5.
///
/// Same purity contract as `SmartReminderGenerating`: pure inputs in,
/// payloads out, no I/O. Awareness payloads are *per-currency* — never mix
/// currencies into a single message (§9.12).
protocol AwarenessGenerating: Sendable {
    @MainActor
    func generate(
        windows: [FinancialLoadWindow],
        currencyFormatter: CurrencyFormatting,
        relativeTo now: Date,
        calendar: Calendar
    ) -> [AwarenessPayload]
}

/// Rule-based default. Three rules in order:
///
/// 1. **Horizon pressure** — for each currency, when the next 7 days carries
///    `.heavy` or `.peak` tone, fire an awareness payload Sunday evening
///    ("Heads up — ₺780 in the next 3 days"). One payload per currency.
///
/// 2. **Daily peak** — when the use case surfaces a `dailyPeak` inside the
///    next 7 days, fire a payload the previous morning naming the day and
///    the amount.
///
/// 3. **Trend up** — reserved. Phase 9 ships the protocol slot but no rule;
///    a future phase will compare this month's average to last month and
///    emit a "trending up" payload. The slot exists so the architecture is
///    forward-ready without an additional generator type.
struct RuleBasedAwarenessGenerator: AwarenessGenerating {

    let pressureFireHour: Int = 19   // 7pm previous day
    let peakFireHour: Int = 9        // morning of previous day

    @MainActor
    func generate(
        windows: [FinancialLoadWindow],
        currencyFormatter: CurrencyFormatting,
        relativeTo now: Date,
        calendar: Calendar
    ) -> [AwarenessPayload] {

        var output: [AwarenessPayload] = []

        for window in windows where window.horizon.dayCount == 7 && !window.isEmpty {
            if let pressure = makeHorizonPressure(
                window: window,
                currencyFormatter: currencyFormatter,
                now: now,
                calendar: calendar
            ) {
                output.append(pressure)
            }
            if let peak = makeDailyPeak(
                window: window,
                currencyFormatter: currencyFormatter,
                now: now,
                calendar: calendar
            ) {
                output.append(peak)
            }
        }
        return output
    }

    // MARK: - Horizon pressure

    private func makeHorizonPressure(
        window: FinancialLoadWindow,
        currencyFormatter: CurrencyFormatting,
        now: Date,
        calendar: Calendar
    ) -> AwarenessPayload? {
        guard window.tone == .heavy || window.tone == .peak else { return nil }

        // Fire Sunday at 7pm so the user opens Monday morning aware.
        guard let fireDate = nextWeekdayEvening(weekday: 1 /* Sunday */, hour: pressureFireHour, from: now, calendar: calendar) else {
            return nil
        }
        let amountText = currencyFormatter.string(
            from: window.totalAmount,
            currencyCode: window.currencyCode
        )
        return AwarenessPayload(
            kind: .horizonPressure,
            anchorDate: calendar.startOfDay(for: fireDate),
            fireDate: fireDate,
            title: Strings.Notifications.awarenessHorizonTitle,
            body: Strings.Notifications.awarenessHorizonBody(amount: amountText, days: 7),
            currencyCode: window.currencyCode
        )
    }

    // MARK: - Daily peak

    private func makeDailyPeak(
        window: FinancialLoadWindow,
        currencyFormatter: CurrencyFormatting,
        now: Date,
        calendar: Calendar
    ) -> AwarenessPayload? {
        guard let peak = window.dailyPeak else { return nil }
        guard let evening = calendar.date(
            bySettingHour: peakFireHour, minute: 0, second: 0,
            of: calendar.date(byAdding: .day, value: -1, to: peak.date) ?? peak.date
        ), evening > now else { return nil }

        let amountText = currencyFormatter.string(from: peak.amount, currencyCode: window.currencyCode)
        let dateText = DateFormatter.localizedString(
            from: peak.date, dateStyle: .medium, timeStyle: .none
        )
        return AwarenessPayload(
            kind: .horizonPressure,
            anchorDate: peak.date,
            fireDate: evening,
            title: Strings.Notifications.awarenessPeakTitle,
            body: Strings.Notifications.awarenessPeakBody(date: dateText, amount: amountText),
            currencyCode: window.currencyCode
        )
    }

    // MARK: - Helpers

    private func nextWeekdayEvening(
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
