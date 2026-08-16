import Foundation

@MainActor
final class InsightsViewModel {

    /// One chip in the currency strip above the Insights surface.
    struct CurrencyChip: Hashable {
        let code: String
        let title: String     // "TRY  ₺"
        let isSelected: Bool
    }

    struct Snapshot: Hashable {
        let currencyChips: [CurrencyChip]
        let selectedCurrencyCode: String
        let monthlyTotal: String
        let yearlyProjection: String
        let activeCount: Int
        let largestUpcoming: LargestUpcoming?
        let breakdown: CategoryBreakdownChartView.ViewModel
        let projection: [ProjectionRow]
        let pressureTiles: [PressureTile]
    }

    /// One tile in the 8-week Pressure strip (§9.8). Per-currency — the
    /// strip mirrors the active currency chip selection.
    struct PressureTile: Hashable {
        let weekLabel: String              // "Nov 25"
        let amountText: String             // currency-formatted
        let tone: FinancialLoadWindow.Tone
        let count: Int
    }

    struct LargestUpcoming: Hashable {
        let name: String
        let amountText: String
        let dateText: String
    }

    struct ProjectionRow: Hashable {
        let weekLabel: String
        let amountText: String
        let count: Int
    }

    private let subscriptionRepository: SubscriptionRepository
    private let categoryRepository: CategoryRepository
    private let currencyFormatter: CurrencyFormatting
    private let currencyManager: CurrencyManaging
    private let dateProvider: DateProviding

    private let monthlySpend = MonthlySpendCalculator()
    private let yearlyProjectionCalc = YearlyProjectionCalculator()
    private let breakdownCalculator = CategoryBreakdownCalculator()
    private let projectionCalculator: RenewalProjectionCalculator

    private var categoriesByID: [UUID: Category] = [:]
    private var observationTask: Task<Void, Never>?
    private var preferredCurrencyObservationTask: Task<Void, Never>?
    private var latestItems: [Subscription] = []
    /// `nil` until the first publish; then sticky to the user's pick unless the
    /// pick disappears from the available set (in which case we re-default to
    /// the preferred display currency).
    private var selectedCurrencyCode: String?

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?

    init(
        subscriptionRepository: SubscriptionRepository,
        categoryRepository: CategoryRepository,
        currencyFormatter: CurrencyFormatting,
        currencyManager: CurrencyManaging,
        dateProvider: DateProviding
    ) {
        self.subscriptionRepository = subscriptionRepository
        self.categoryRepository = categoryRepository
        self.currencyFormatter = currencyFormatter
        self.currencyManager = currencyManager
        self.dateProvider = dateProvider
        self.projectionCalculator = RenewalProjectionCalculator(calendar: dateProvider.calendar)
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

    func selectCurrency(_ code: String) {
        guard selectedCurrencyCode != code else { return }
        selectedCurrencyCode = code
        publish(items: latestItems)
    }

    private func observePreferredCurrency() {
        preferredCurrencyObservationTask?.cancel()
        preferredCurrencyObservationTask = Task { [weak self] in
            guard let self else { return }
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

        // Available currencies, sorted: preferred first → by count desc → by code.
        let preferredCode = currencyManager.preferredDisplayCurrency.code
        let counts = Dictionary(grouping: active, by: { $0.currencyCode })
            .mapValues { $0.count }
        let availableCodes = counts.keys.sorted { lhs, rhs in
            if lhs == preferredCode { return true }
            if rhs == preferredCode { return false }
            let lc = counts[lhs] ?? 0
            let rc = counts[rhs] ?? 0
            if lc != rc { return lc > rc }
            return lhs < rhs
        }

        // Settle the selected currency. If the user's previous pick disappeared
        // (e.g. last subscription in that currency was archived), fall back to
        // the first available, which keeps the surface aggregated, not blank.
        let resolvedSelected: String
        if let pick = selectedCurrencyCode, availableCodes.contains(pick) {
            resolvedSelected = pick
        } else {
            resolvedSelected = availableCodes.first ?? preferredCode
            selectedCurrencyCode = resolvedSelected
        }

        let chips = availableCodes.map { code -> CurrencyChip in
            CurrencyChip(
                code: code,
                title: chipTitle(for: code),
                isSelected: code == resolvedSelected
            )
        }

        // All downstream numbers are computed from the slice in the *selected*
        // currency. Mixing across currencies in a single number is forbidden
        // until FX ships — see roadmap §8.6.
        let scoped = active.filter { $0.currencyCode == resolvedSelected }
        let monthly = monthlySpend(scoped)
        let yearly = yearlyProjectionCalc(scoped)

        let breakdownRows = breakdownCalculator(scoped).map { result -> CategoryBreakdownChartView.ViewModel.Row in
            let category = result.categoryID.flatMap { categoriesByID[$0] }
            return CategoryBreakdownChartView.ViewModel.Row(
                title: category?.name ?? Strings.SubscriptionList.uncategorized,
                valueText: currencyFormatter.string(from: result.total, currencyCode: resolvedSelected),
                share: result.share,
                systemIcon: category?.systemIconName ?? "square.grid.2x2"
            )
        }
        let projectionRows = projectionCalculator(scoped, weeks: 4, relativeTo: dateProvider.now)
            .map { bucket -> ProjectionRow in
                ProjectionRow(
                    weekLabel: weekFormatter.string(from: bucket.weekStart),
                    amountText: currencyFormatter.string(from: bucket.total, currencyCode: resolvedSelected),
                    count: bucket.count
                )
            }
        let largest = largestUpcoming(in: scoped)
        let pressureTiles = makePressureTiles(
            scoped: scoped,
            currencyCode: resolvedSelected,
            monthlyAverage: monthly
        )

        state = .loaded(Snapshot(
            currencyChips: chips,
            selectedCurrencyCode: resolvedSelected,
            monthlyTotal: currencyFormatter.string(from: monthly, currencyCode: resolvedSelected),
            yearlyProjection: currencyFormatter.string(from: yearly, currencyCode: resolvedSelected),
            activeCount: scoped.count,
            largestUpcoming: largest,
            breakdown: CategoryBreakdownChartView.ViewModel(rows: breakdownRows),
            projection: projectionRows,
            pressureTiles: pressureTiles
        ))
    }

    /// 8-week pressure strip (§9.8). Per-tile tone is derived against the
    /// user's monthly average for the selected currency — same scale as the
    /// FinancialLoad view, so the colour language stays consistent across
    /// surfaces.
    private func makePressureTiles(
        scoped: [Subscription],
        currencyCode: String,
        monthlyAverage: Decimal
    ) -> [PressureTile] {
        let buckets = projectionCalculator(scoped, weeks: 8, relativeTo: dateProvider.now)
        return buckets.map { bucket in
            let tone = pressureTone(
                weeklyTotal: bucket.total,
                monthlyAverage: monthlyAverage
            )
            return PressureTile(
                weekLabel: weekFormatter.string(from: bucket.weekStart),
                amountText: currencyFormatter.string(from: bucket.total, currencyCode: currencyCode),
                tone: tone,
                count: bucket.count
            )
        }
    }

    /// Same thresholds as `UpcomingFinancialLoadUseCase` — a week's load is
    /// normalised to a monthly equivalent (× 4.33), then compared to the
    /// user's monthly average.
    private func pressureTone(weeklyTotal: Decimal, monthlyAverage: Decimal) -> FinancialLoadWindow.Tone {
        guard monthlyAverage > 0, weeklyTotal > 0 else {
            return weeklyTotal > 0 ? .moderate : .light
        }
        let monthlyEquivalent = weeklyTotal * Decimal(string: "4.33")!
        let ratio = monthlyEquivalent / monthlyAverage
        switch ratio {
        case ...Decimal(0.25): return .light
        case ...Decimal(0.60): return .moderate
        case ...Decimal(1.00): return .heavy
        default: return .peak
        }
    }

    private func chipTitle(for code: String) -> String {
        guard let currency = currencyManager.currency(for: code) else { return code }
        return "\(currency.code)  \(currency.symbol)"
    }

    private func largestUpcoming(in subscriptions: [Subscription]) -> LargestUpcoming? {
        let calendar = dateProvider.calendar
        let now = dateProvider.now
        guard let end = calendar.date(byAdding: .day, value: 30, to: now) else { return nil }
        let inWindow = subscriptions.filter { $0.nextRenewalDate >= now && $0.nextRenewalDate <= end }
        guard let top = inWindow.max(by: { $0.amount < $1.amount }) else { return nil }
        return LargestUpcoming(
            name: top.name,
            amountText: currencyFormatter.string(from: top.amount, currencyCode: top.currencyCode),
            dateText: longDateFormatter.string(from: top.nextRenewalDate)
        )
    }

    private var weekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = dateProvider.calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }

    private var longDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = dateProvider.calendar
        formatter.dateStyle = .medium
        return formatter
    }
}
