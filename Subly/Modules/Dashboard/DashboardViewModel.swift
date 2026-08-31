import Foundation

@MainActor
final class DashboardViewModel {

    struct CurrencyTotal: Hashable {
        /// ISO 4217 code — drives glyph + locale via `CurrencyManaging`.
        let currencyCode: String
        let amountText: String
        /// Honest yearly projection (monthly × 12), formatted in the same currency.
        let yearlyText: String
        let activeCount: Int
    }

    /// Roadmap §9.4 — one card per currency for the next 7 days, only when
    /// non-empty. Tapping opens `FinancialLoadCoordinator` for that currency.
    struct PressureCard: Hashable {
        let currencyCode: String
        let totalText: String     // "₺1,240"
        let countText: String     // "4 renewals"
        let toneText: String      // "moderate"
        let tone: FinancialLoadWindow.Tone
    }

    struct UpcomingRow: Hashable {
        let subscription: Subscription
        let name: String
        let dateText: String
        let amountText: String
        let avatarSystemIcon: String
        /// Renews today/tomorrow — meta line tints accent (v5).
        let isImminent: Bool
    }

    /// One bar of the hero 6-month mini chart.
    struct TrendMonth: Hashable {
        /// Single-letter month label ("J", "F"…).
        let letter: String
        /// Normalized 0…1 against the series maximum.
        let normalized: Double
        let isCurrent: Bool
    }

    /// One segment of the "By category" proportional bar.
    struct CategorySegment: Hashable {
        let name: String
        let fraction: Double
        let totalText: String
    }

    /// One chip of the hero currency selector — shown only when subscriptions
    /// span 2+ currencies. Chip order is stable (preferred currency first),
    /// independent of which chip is selected.
    struct CurrencyChip: Hashable {
        let currencyCode: String
        /// "₺ TRY", "$ USD" — glyph + ISO code.
        let title: String
        let isSelected: Bool
    }

    struct Snapshot: Hashable {
        /// Selected currency first — the hero renders `totals.first`.
        let totals: [CurrencyTotal]
        /// Currency selector chips; empty when only one currency is in use.
        let currencyChips: [CurrencyChip]
        let pressure: [PressureCard]
        let totalActiveCount: Int
        let upcoming: [UpcomingRow]
        /// v5 hero chart — projected spend for the last 6 months (selected
        /// currency), derived from subscription start dates.
        let trend: [TrendMonth]
        /// "▾ 4% vs June" — nil when there is no prior-month data to compare.
        let deltaText: String?
        let deltaIsDown: Bool
        /// v5 category bar segments (selected currency), largest first.
        let categories: [CategorySegment]
    }

    private let subscriptionRepository: SubscriptionRepository
    private let categoryRepository: CategoryRepository
    private let currencyFormatter: CurrencyFormatting
    private let currencyManager: CurrencyManaging
    private let dateProvider: DateProviding
    private let sampleDataSeeder: SampleDataSeeding
    private let calculateMonthlyTotal = MonthlySpendCalculator()
    private let upcomingUseCase: UpcomingRenewalsUseCase
    private let financialLoadUseCase: UpcomingFinancialLoadUseCase

    private var observationTask: Task<Void, Never>?
    private var preferredCurrencyObservationTask: Task<Void, Never>?
    private var categoriesByID: [UUID: Category] = [:]
    private var latestItems: [Subscription] = []
    /// Explicit chip selection; nil follows the default (preferred display
    /// currency, or the most-used currency when the preferred one has no
    /// subscriptions). Session-only — resets on relaunch.
    private var selectedCurrencyCode: String?

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onAddSubscriptionTapped: (() -> Void)?
    var onSelectSubscription: ((Subscription) -> Void)?
    /// Tapped a Pressure card — currency code carried for deep-scroll.
    var onPressureCardTapped: ((String) -> Void)?
    /// Tapped "See all" on the upcoming-renewals header.
    var onSeeAllUpcomingTapped: (() -> Void)?
    /// Tapped the hero card — opens Insights.
    var onShowInsights: (() -> Void)?
    /// Tapped the header avatar — opens Settings (v5: not a tab).
    var onShowSettings: (() -> Void)?

    init(
        subscriptionRepository: SubscriptionRepository,
        categoryRepository: CategoryRepository,
        currencyFormatter: CurrencyFormatting,
        currencyManager: CurrencyManaging,
        dateProvider: DateProviding,
        sampleDataSeeder: SampleDataSeeding
    ) {
        self.subscriptionRepository = subscriptionRepository
        self.categoryRepository = categoryRepository
        self.currencyFormatter = currencyFormatter
        self.currencyManager = currencyManager
        self.dateProvider = dateProvider
        self.sampleDataSeeder = sampleDataSeeder
        self.upcomingUseCase = UpcomingRenewalsUseCase(
            calendar: dateProvider.calendar,
            now: { dateProvider.now }
        )
        self.financialLoadUseCase = UpcomingFinancialLoadUseCase(
            calendar: dateProvider.calendar,
            now: { dateProvider.now }
        )
    }

    deinit {
        observationTask?.cancel()
        preferredCurrencyObservationTask?.cancel()
    }

    func start() {
        state = .loading
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            if let categories = try? await categoryRepository.fetchAll() {
                self.categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            }
            let stream = subscriptionRepository.observe()
            for await items in stream {
                if Task.isCancelled { return }
                self.latestItems = items
                self.publish(items: items)
            }
        }
        observePreferredCurrency()
    }

    func didTapAdd() {
        onAddSubscriptionTapped?()
    }

    /// Hero currency chip tapped — rescope the dashboard to that currency.
    func selectCurrency(_ code: String) {
        guard code != selectedCurrencyCode else { return }
        selectedCurrencyCode = code
        publish(items: latestItems)
    }

    func didSelectUpcoming(_ subscription: Subscription) {
        onSelectSubscription?(subscription)
    }

    func didTapPressureCard(currencyCode: String) {
        onPressureCardTapped?(currencyCode)
    }

    func didTapSeeAllUpcoming() {
        onSeeAllUpcomingTapped?()
    }

    func didTapHero() {
        onShowInsights?()
    }

    func didTapSettings() {
        onShowSettings?()
    }

    /// Empty state (v5 screen 12) "Try with sample data" — the repository
    /// stream refreshes the dashboard once fixtures land.
    func didTapSampleData() {
        Task { [weak self] in
            await self?.sampleDataSeeder.seedIfEmpty()
        }
    }

    /// "Renews today" / "Renews tomorrow" / "Renews Jul 4".
    private func renewalText(daysAway: Int, date: Date) -> String {
        switch daysAway {
        case 0: return Strings.SubscriptionList.renewsOn(Strings.SubscriptionDetail.dueToday)
        case 1: return Strings.SubscriptionList.renewsOn(Strings.SubscriptionDetail.dueTomorrow)
        default: return Strings.SubscriptionList.renewsOn(dateFormatter.string(from: date))
        }
    }

    private func observePreferredCurrency() {
        preferredCurrencyObservationTask?.cancel()
        preferredCurrencyObservationTask = Task { [weak self] in
            guard let self else { return }
            // Skip the first yield — it matches the value already in use at
            // initial render and would cause a redundant rebuild.
            var skippedInitial = false
            for await _ in currencyManager.observe() {
                if Task.isCancelled { return }
                guard skippedInitial else { skippedInitial = true; continue }
                self.publish(items: self.latestItems)
            }
        }
    }

    private func publish(items: [Subscription]) {
        let active = items.filter { !$0.isArchived }
        guard !active.isEmpty else {
            state = .empty
            return
        }

        // Stable order (preferred first, then most-used) drives the chip row;
        // the hero renders whichever currency is selected.
        let orderedTotals = makeCurrencyTotals(from: active)
        if let explicit = selectedCurrencyCode,
           !orderedTotals.contains(where: { $0.currencyCode == explicit }) {
            // Selected currency lost its last subscription — fall back to default.
            selectedCurrencyCode = nil
        }
        let selectedCode = selectedCurrencyCode ?? orderedTotals.first?.currencyCode
        var totals = orderedTotals
        if let index = totals.firstIndex(where: { $0.currencyCode == selectedCode }), index > 0 {
            totals.insert(totals.remove(at: index), at: 0)
        }

        let currencyChips: [CurrencyChip] = orderedTotals.count >= 2
            ? orderedTotals.map { total in
                let symbol = currencyManager.currency(for: total.currencyCode)?.symbol
                return CurrencyChip(
                    currencyCode: total.currencyCode,
                    title: [symbol, total.currencyCode].compactMap { $0 }.joined(separator: " "),
                    isSelected: total.currencyCode == selectedCode
                )
            }
            : []

        let selectedSubs = active.filter { $0.currencyCode == selectedCode }
        let pressure = makePressureCards(from: active)
        let calendar = dateProvider.calendar
        let startOfToday = calendar.startOfDay(for: dateProvider.now)
        let upcoming = upcomingUseCase(selectedSubs, withinDays: 7).map { sub in
            let category = sub.categoryID.flatMap { categoriesByID[$0] }
            let days = calendar.dateComponents(
                [.day],
                from: startOfToday,
                to: calendar.startOfDay(for: sub.nextRenewalDate)
            ).day ?? Int.max
            return UpcomingRow(
                subscription: sub,
                name: sub.name,
                dateText: renewalText(daysAway: days, date: sub.nextRenewalDate),
                amountText: currencyFormatter.string(from: sub.amount, currencyCode: sub.currencyCode),
                avatarSystemIcon: category?.systemIconName ?? "creditcard",
                isImminent: days <= 1
            )
        }

        let (trend, deltaText, deltaIsDown) = makeTrend(from: selectedSubs)

        state = .loaded(Snapshot(
            totals: totals,
            currencyChips: currencyChips,
            pressure: pressure,
            totalActiveCount: selectedSubs.count,
            upcoming: upcoming,
            trend: trend,
            deltaText: deltaText,
            deltaIsDown: deltaIsDown,
            categories: makeCategorySegments(from: selectedSubs)
        ))
    }

    /// Projected monthly totals for the trailing 6 months, derived from each
    /// subscription's `startDate` (a subscription contributes its monthly
    /// equivalent to every month since it started). Honest: no payment history
    /// is stored in v1, so this is a projection, and the delta is only shown
    /// when the previous month has data.
    private func makeTrend(from subs: [Subscription]) -> ([TrendMonth], String?, Bool) {
        let calendar = dateProvider.calendar
        let now = dateProvider.now
        var months: [(date: Date, total: Decimal)] = []
        for offset in stride(from: -5, through: 0, by: 1) {
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: now),
                  let monthEnd = calendar.dateInterval(of: .month, for: monthDate)?.end else { continue }
            let total = subs
                .filter { $0.startDate < monthEnd }
                .reduce(Decimal(0)) { $0 + calculateMonthlyTotal.monthlyEquivalent(of: $1) }
            months.append((monthDate, total))
        }

        let maxTotal = months.map(\.total).max() ?? 0
        let maxDouble = NSDecimalNumber(decimal: maxTotal).doubleValue
        let letterFormatter = DateFormatter()
        letterFormatter.calendar = calendar
        letterFormatter.setLocalizedDateFormatFromTemplate("MMMMM") // single letter

        let trend = months.enumerated().map { index, month in
            TrendMonth(
                letter: letterFormatter.string(from: month.date),
                normalized: maxDouble > 0
                    ? NSDecimalNumber(decimal: month.total).doubleValue / maxDouble
                    : 0,
                isCurrent: index == months.count - 1
            )
        }

        // Delta vs previous month — only when both months are non-zero.
        var deltaText: String?
        var deltaIsDown = false
        if months.count >= 2 {
            let current = NSDecimalNumber(decimal: months[months.count - 1].total).doubleValue
            let previous = NSDecimalNumber(decimal: months[months.count - 2].total).doubleValue
            if previous > 0, current != previous {
                let percent = Int((abs(current - previous) / previous * 100).rounded())
                if percent > 0 {
                    deltaIsDown = current < previous
                    let monthName = DateFormatter()
                    monthName.calendar = calendar
                    monthName.setLocalizedDateFormatFromTemplate("MMMM")
                    let prevName = monthName.string(from: months[months.count - 2].date)
                    deltaText = String(
                        format: Strings.Dashboard.deltaFormat,
                        deltaIsDown ? "▾" : "▴",
                        percent,
                        prevName
                    )
                }
            }
        }
        return (trend, deltaText, deltaIsDown)
    }

    private func makeCategorySegments(from subs: [Subscription]) -> [CategorySegment] {
        let breakdown = CategoryBreakdownCalculator()(subs)
        guard let currency = subs.first?.currencyCode else { return [] }
        return breakdown.prefix(4).map { result in
            let name = result.categoryID.flatMap { categoriesByID[$0]?.localizedName }
                ?? Strings.SubscriptionList.uncategorized
            return CategorySegment(
                name: name,
                fraction: result.share,
                totalText: currencyFormatter.string(from: result.total, currencyCode: currency)
            )
        }
    }

    /// Per-currency 7-day pressure cards. Empty currencies are dropped
    /// silently so the Dashboard never carries dead surface (§9.4).
    private func makePressureCards(from active: [Subscription]) -> [PressureCard] {
        let monthlyByCurrency = Dictionary(grouping: active, by: \.currencyCode)
            .mapValues { subs in
                subs.reduce(Decimal(0)) { partial, sub in
                    partial + calculateMonthlyTotal.monthlyEquivalent(of: sub)
                }
            }
        let windows = financialLoadUseCase(
            active,
            horizons: [.next7d],
            monthlyAverageByCurrency: monthlyByCurrency
        )
        let preferredCode = currencyManager.preferredDisplayCurrency.code
        let cards = windows
            .filter { !$0.isEmpty }
            .map { window -> PressureCard in
                PressureCard(
                    currencyCode: window.currencyCode,
                    totalText: currencyFormatter.string(
                        from: window.totalAmount,
                        currencyCode: window.currencyCode
                    ),
                    countText: Strings.FinancialLoad.renewals(window.subscriptionCount),
                    toneText: Strings.FinancialLoad.toneLabel(window.tone),
                    tone: window.tone
                )
            }
        return cards.sorted { lhs, rhs in
            if lhs.currencyCode == preferredCode { return true }
            if rhs.currencyCode == preferredCode { return false }
            return lhs.currencyCode < rhs.currencyCode
        }
    }

    /// Group active subscriptions by currency and compute a monthly-equivalent
    /// total per group. **Never** mixes currencies into a single number — see
    /// roadmap §8.6 "Honest aggregation".
    private func makeCurrencyTotals(from active: [Subscription]) -> [CurrencyTotal] {
        let grouped = Dictionary(grouping: active, by: { $0.currencyCode })
        let preferredCode = currencyManager.preferredDisplayCurrency.code

        let totals = grouped.map { (code, group) -> CurrencyTotal in
            let monthly = calculateMonthlyTotal(group)
            return CurrencyTotal(
                currencyCode: code,
                amountText: currencyFormatter.string(from: monthly, currencyCode: code),
                yearlyText: currencyFormatter.string(from: monthly * 12, currencyCode: code),
                activeCount: group.count
            )
        }

        return totals.sorted { lhs, rhs in
            // Preferred currency first; then by active count descending;
            // then by code for a stable order.
            if lhs.currencyCode == preferredCode { return true }
            if rhs.currencyCode == preferredCode { return false }
            if lhs.activeCount != rhs.activeCount { return lhs.activeCount > rhs.activeCount }
            return lhs.currencyCode < rhs.currencyCode
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.calendar = dateProvider.calendar
        return formatter
    }
}
