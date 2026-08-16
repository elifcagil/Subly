import Foundation

@MainActor
final class FinancialLoadViewModel {

    // MARK: - View types

    /// One horizon card inside a currency section.
    struct HorizonCard: Hashable {
        let horizonTitle: String          // localized "Next 24 hours" / etc
        let totalText: String             // currency-formatted
        let subtitleText: String          // "4 renewals · moderate"
        let peakText: String?             // optional "Heaviest day · …"
        let tone: FinancialLoadWindow.Tone
        let isEmpty: Bool
        let emptyText: String?            // localized "No renewals in the next 7 days"
    }

    /// One currency section.
    struct Section: Hashable {
        let currencyCode: String          // shown in the section header chip
        let cards: [HorizonCard]
    }

    struct Snapshot: Hashable {
        let sections: [Section]
    }

    // MARK: - Dependencies

    private let subscriptionRepository: SubscriptionRepository
    private let currencyFormatter: CurrencyFormatting
    private let currencyManager: CurrencyManaging
    private let dateProvider: DateProviding

    private let useCase: UpcomingFinancialLoadUseCase
    private let monthlySpend = MonthlySpendCalculator()

    private var observationTask: Task<Void, Never>?

    /// Currency to scroll to on initial load. `nil` = preferred currency.
    private var initialCurrencyCode: String?

    /// Sticky horizons in the order they should render. Bringing the longest
    /// last keeps the eye flowing from "now" to "later" (UX rule §9.3).
    private let horizons: [FinancialLoadWindow.Horizon] = [.next24h, .next7d, .next30d]

    // MARK: - State

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    /// Emitted once after the first snapshot — tells the VC which section
    /// to scroll into view if a specific currency was requested.
    var onScrollToCurrencyRequested: ((String) -> Void)?

    init(
        subscriptionRepository: SubscriptionRepository,
        currencyFormatter: CurrencyFormatting,
        currencyManager: CurrencyManaging,
        dateProvider: DateProviding,
        initialCurrencyCode: String? = nil
    ) {
        self.subscriptionRepository = subscriptionRepository
        self.currencyFormatter = currencyFormatter
        self.currencyManager = currencyManager
        self.dateProvider = dateProvider
        self.initialCurrencyCode = initialCurrencyCode
        self.useCase = UpcomingFinancialLoadUseCase(
            calendar: dateProvider.calendar,
            now: { dateProvider.now }
        )
    }

    deinit {
        observationTask?.cancel()
    }

    func start() {
        state = .loading
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            let stream = subscriptionRepository.observe()
            for await items in stream {
                if Task.isCancelled { return }
                self.publish(items: items)
            }
        }
    }

    // MARK: - Snapshot

    private func publish(items: [Subscription]) {
        let active = items.filter { !$0.isArchived }
        guard !active.isEmpty else {
            state = .empty
            return
        }

        // Per-currency monthly averages drive the Tone calculation. We use
        // `MonthlySpendCalculator.monthlyEquivalent(of:)` per subscription so
        // the same definition of "monthly" applies everywhere in the app.
        let monthlyByCurrency = Dictionary(grouping: active, by: \.currencyCode)
            .mapValues { subs in
                subs.reduce(Decimal(0)) { partial, sub in
                    partial + monthlySpend.monthlyEquivalent(of: sub)
                }
            }

        let windows = useCase(
            active,
            horizons: horizons,
            monthlyAverageByCurrency: monthlyByCurrency
        )

        let sections = makeSections(from: windows)
        guard !sections.isEmpty else {
            state = .empty
            return
        }
        state = .loaded(Snapshot(sections: sections))

        // First load: scroll to requested currency (or preferred if none).
        if let requested = initialCurrencyCode {
            onScrollToCurrencyRequested?(requested)
            initialCurrencyCode = nil
        }
    }

    private func makeSections(from windows: [FinancialLoadWindow]) -> [Section] {
        let preferred = currencyManager.preferredDisplayCurrency.code
        let byCurrency = Dictionary(grouping: windows, by: \.currencyCode)

        // Order: preferred first, then alphabetical for stability.
        let codes = byCurrency.keys.sorted { lhs, rhs in
            if lhs == preferred { return true }
            if rhs == preferred { return false }
            return lhs < rhs
        }

        return codes.map { code in
            let cards = horizons.map { horizon -> HorizonCard in
                let window = byCurrency[code]?.first(where: { $0.horizon == horizon })
                return makeCard(for: horizon, currencyCode: code, window: window)
            }
            return Section(currencyCode: code, cards: cards)
        }
    }

    private func makeCard(
        for horizon: FinancialLoadWindow.Horizon,
        currencyCode: String,
        window: FinancialLoadWindow?
    ) -> HorizonCard {
        let title = horizonTitle(horizon)
        guard let window, !window.isEmpty else {
            return HorizonCard(
                horizonTitle: title,
                totalText: "—",
                subtitleText: "",
                peakText: nil,
                tone: .light,
                isEmpty: true,
                emptyText: emptyText(for: horizon)
            )
        }

        let total = currencyFormatter.string(from: window.totalAmount, currencyCode: currencyCode)
        let countText = Strings.FinancialLoad.renewals(window.subscriptionCount)
        let toneText = Strings.FinancialLoad.toneLabel(window.tone)
        let subtitle = "\(countText) · \(toneText)"

        let peakText: String?
        if let peak = window.dailyPeak {
            let dateText = dateFormatter.string(from: peak.date)
            let amountText = currencyFormatter.string(from: peak.amount, currencyCode: currencyCode)
            peakText = Strings.FinancialLoad.heaviestDay(date: dateText, amount: amountText)
        } else {
            peakText = nil
        }

        return HorizonCard(
            horizonTitle: title,
            totalText: total,
            subtitleText: subtitle,
            peakText: peakText,
            tone: window.tone,
            isEmpty: false,
            emptyText: nil
        )
    }

    private func horizonTitle(_ horizon: FinancialLoadWindow.Horizon) -> String {
        switch horizon {
        case .next24h: return Strings.FinancialLoad.horizon24h
        case .next7d: return Strings.FinancialLoad.horizon7d
        case .next30d: return Strings.FinancialLoad.horizon30d
        case .customDays(let n): return Strings.FinancialLoad.horizonCustom(n)
        }
    }

    private func emptyText(for horizon: FinancialLoadWindow.Horizon) -> String {
        switch horizon {
        case .next24h: return Strings.FinancialLoad.empty24h
        case .next7d: return Strings.FinancialLoad.empty7d
        case .next30d: return Strings.FinancialLoad.empty30d
        case .customDays: return Strings.FinancialLoad.empty7d
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = dateProvider.calendar
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
