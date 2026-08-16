import Foundation

/// Computes one `FinancialLoadWindow` per (horizon × currency) combination
/// present in the user's active subscriptions.
///
/// Roadmap §9.2. Pure function over inputs — no repositories, no managers,
/// no side effects. Caller passes the data; the use case returns the windows.
struct UpcomingFinancialLoadUseCase {

    private let calendar: Calendar
    private let now: () -> Date

    /// When the heaviest day in a window is below this fraction of the
    /// window total, the use case suppresses `dailyPeak` so the UI can
    /// render unconditionally.
    private let peakSignificanceThreshold: Decimal = Decimal(0.4)

    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }

    /// - Parameters:
    ///   - subscriptions: full input set. The use case filters archived
    ///     itself; callers don't need to pre-filter.
    ///   - horizons: which windows to materialise. The default trio (24h /
    ///     7d / 30d) matches §9.1 in scope.
    ///   - monthlyAverageByCurrency: per-currency monthly equivalent
    ///     average; used to compute `Tone`. Pass `0` for currencies with no
    ///     history to force `.light`.
    func callAsFunction(
        _ subscriptions: [Subscription],
        horizons: [FinancialLoadWindow.Horizon] = [.next24h, .next7d, .next30d],
        monthlyAverageByCurrency: [String: Decimal]
    ) -> [FinancialLoadWindow] {

        let active = subscriptions.filter { !$0.isArchived }
        guard !active.isEmpty else { return [] }

        let currencies = Set(active.map(\.currencyCode))
        let reference = now()

        var output: [FinancialLoadWindow] = []
        for horizon in horizons {
            for code in currencies.sorted() {
                let window = makeWindow(
                    horizon: horizon,
                    currencyCode: code,
                    active: active,
                    monthlyAverage: monthlyAverageByCurrency[code] ?? 0,
                    reference: reference
                )
                output.append(window)
            }
        }
        return output
    }

    // MARK: - Per-window construction

    private func makeWindow(
        horizon: FinancialLoadWindow.Horizon,
        currencyCode: String,
        active: [Subscription],
        monthlyAverage: Decimal,
        reference: Date
    ) -> FinancialLoadWindow {

        let inWindow = subscriptionsInWindow(
            active: active,
            currencyCode: currencyCode,
            horizon: horizon,
            reference: reference
        )

        let total = inWindow.reduce(Decimal(0)) { $0 + $1.amount }
        let count = inWindow.count

        let tone = makeTone(
            windowTotal: total,
            monthlyAverage: monthlyAverage,
            horizon: horizon
        )

        let peak = makeDailyPeak(from: inWindow, total: total)

        return FinancialLoadWindow(
            horizon: horizon,
            currencyCode: currencyCode,
            totalAmount: total,
            subscriptionCount: count,
            tone: tone,
            dailyPeak: peak
        )
    }

    private func subscriptionsInWindow(
        active: [Subscription],
        currencyCode: String,
        horizon: FinancialLoadWindow.Horizon,
        reference: Date
    ) -> [Subscription] {
        guard let end = calendar.date(
            byAdding: .day,
            value: horizon.dayCount,
            to: reference
        ) else { return [] }

        return active.filter { sub in
            sub.currencyCode == currencyCode
            && sub.nextRenewalDate >= reference
            && sub.nextRenewalDate <= end
        }
    }

    /// Tone is the window-equivalent share of the user's monthly average.
    /// Horizons shorter than a month are first normalised to a monthly
    /// equivalent so that a 24h heavy ratio doesn't read the same as a 30d
    /// heavy ratio.
    private func makeTone(
        windowTotal: Decimal,
        monthlyAverage: Decimal,
        horizon: FinancialLoadWindow.Horizon
    ) -> FinancialLoadWindow.Tone {
        guard monthlyAverage > 0, windowTotal > 0 else {
            return windowTotal > 0 ? .moderate : .light
        }
        // Normalise the window to a 30-day equivalent so all horizons share
        // the same scale. A 24h window with ₺560 → 560 * 30 / 1 = ₺16,800
        // equivalent, which is heavy against a ₺2,000 average.
        let days = max(Decimal(horizon.dayCount), Decimal(1))
        let monthlyEquivalent = (windowTotal * Decimal(30)) / days
        let ratio = monthlyEquivalent / monthlyAverage

        switch ratio {
        case ...Decimal(0.25): return .light
        case ...Decimal(0.60): return .moderate
        case ...Decimal(1.00): return .heavy
        default: return .peak
        }
    }

    private func makeDailyPeak(
        from inWindow: [Subscription],
        total: Decimal
    ) -> DailyPeak? {
        guard !inWindow.isEmpty, total > 0 else { return nil }

        let grouped = Dictionary(grouping: inWindow) { sub in
            calendar.startOfDay(for: sub.nextRenewalDate)
        }
        let dayTotals = grouped.map { date, subs -> DailyPeak in
            let dayTotal = subs.reduce(Decimal(0)) { $0 + $1.amount }
            return DailyPeak(date: date, amount: dayTotal, count: subs.count)
        }
        guard let top = dayTotals.max(by: { $0.amount < $1.amount }) else {
            return nil
        }
        // Suppress noise — a peak below the significance threshold means the
        // window is fairly distributed; no point highlighting one day.
        let share = top.amount / total
        return share >= peakSignificanceThreshold ? top : nil
    }
}
