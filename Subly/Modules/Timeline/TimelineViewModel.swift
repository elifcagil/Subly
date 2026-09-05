import Foundation

/// v5 Timeline: week view (screen 06 — week strip + day-grouped cards) and
/// month overview (screen 10 — ‹ › paging, calendar grid, payments list).
@MainActor
final class TimelineViewModel {

    enum Mode: Hashable {
        case week
        case month
    }

    struct WeekDay: Hashable {
        let weekdayLetter: String
        let dayNumber: String
        let isToday: Bool
        let renewalCount: Int
    }

    struct MonthDay: Hashable {
        let dayNumber: String
        let isInMonth: Bool
        let isToday: Bool
        let hasRenewal: Bool
    }

    /// One day's payments in the month list (accent day-number column).
    struct MonthPayments: Hashable {
        let dayNumber: String
        let rows: [RenewalRow]
    }

    struct RenewalRow: Hashable {
        let subscription: Subscription
        let name: String
        let categoryName: String?
        let amountText: String
    }

    struct DayGroup: Hashable {
        /// "Friday, July 4"
        let title: String
        let rows: [RenewalRow]
    }

    struct Snapshot: Hashable {
        let mode: Mode
        /// "July"
        let monthTitle: String
        /// "$71.46 + ₺249,99" — totals renewing this month, one per currency;
        /// nil when none.
        let dueAmountText: String?
        let week: [WeekDay]
        let groups: [DayGroup]

        // Month overview (screen 10) — for the displayed (paged) month.
        /// "July 2026"
        let monthYearTitle: String
        /// Localized MON–SUN header letters in display order.
        let weekdayLetters: [String]
        /// Row-major grid cells (multiple of 7).
        let gridDays: [MonthDay]
        let monthPayments: [MonthPayments]
    }

    private let subscriptionRepository: SubscriptionRepository
    private let categoryRepository: CategoryRepository
    private let currencyFormatter: CurrencyFormatting
    private let dateProvider: DateProviding

    private var observationTask: Task<Void, Never>?
    private var categoriesByID: [UUID: Category] = [:]
    private var latestItems: [Subscription] = []
    private(set) var mode: Mode = .week
    /// Displayed month, as an offset in months from the current one.
    private var monthOffset: Int = 0

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onSelectSubscription: ((Subscription) -> Void)?

    init(
        subscriptionRepository: SubscriptionRepository,
        categoryRepository: CategoryRepository,
        currencyFormatter: CurrencyFormatting,
        dateProvider: DateProviding
    ) {
        self.subscriptionRepository = subscriptionRepository
        self.categoryRepository = categoryRepository
        self.currencyFormatter = currencyFormatter
        self.dateProvider = dateProvider
    }

    deinit {
        observationTask?.cancel()
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
    }

    func didSelect(_ subscription: Subscription) {
        onSelectSubscription?(subscription)
    }

    func setMode(_ newMode: Mode) {
        guard mode != newMode else { return }
        mode = newMode
        if newMode == .week { monthOffset = 0 }
        publish(items: latestItems)
    }

    /// ‹ › month paging (screen 10).
    func stepMonth(_ delta: Int) {
        monthOffset += delta
        publish(items: latestItems)
    }

    // MARK: - Snapshot

    private func publish(items: [Subscription]) {
        let active = items.filter { !$0.isArchived }
        guard !active.isEmpty else {
            state = .empty
            return
        }

        let calendar = dateProvider.calendar
        let now = dateProvider.now
        let displayedMonth = calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now

        state = .loaded(Snapshot(
            mode: mode,
            monthTitle: monthFormatter.string(from: now),
            dueAmountText: dueThisMonth(active, calendar: calendar, now: now),
            week: makeWeek(active, calendar: calendar, now: now),
            groups: makeGroups(active, calendar: calendar, now: now),
            monthYearTitle: monthYearFormatter.string(from: displayedMonth),
            weekdayLetters: makeWeekdayLetters(calendar: calendar),
            gridDays: makeGrid(active, calendar: calendar, now: now, monthDate: displayedMonth),
            monthPayments: makeMonthPayments(active, calendar: calendar, monthDate: displayedMonth)
        ))
    }

    // MARK: Month overview (screen 10)

    /// Localized single-letter weekday headers, starting from the calendar's
    /// first weekday (MON for most locales).
    private func makeWeekdayLetters(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(first + $0) % 7].uppercased() }
    }

    private func makeGrid(
        _ subs: [Subscription],
        calendar: Calendar,
        now: Date,
        monthDate: Date
    ) -> [MonthDay] {
        guard let month = calendar.dateInterval(of: .month, for: monthDate) else { return [] }
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        // Leading blanks: distance from the calendar's first weekday.
        let firstWeekday = calendar.component(.weekday, from: month.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        let renewalDays = Set(
            subs.map { $0.nextRenewalDate }
                .filter { month.contains($0) }
                .map { calendar.component(.day, from: $0) }
        )
        let today = calendar.startOfDay(for: now)

        var cells: [MonthDay] = Array(
            repeating: MonthDay(dayNumber: "", isInMonth: false, isToday: false, hasRenewal: false),
            count: leading
        )
        for day in 1...daysInMonth {
            let date = calendar.date(byAdding: .day, value: day - 1, to: month.start) ?? month.start
            cells.append(MonthDay(
                dayNumber: "\(day)",
                isInMonth: true,
                isToday: calendar.startOfDay(for: date) == today,
                hasRenewal: renewalDays.contains(day)
            ))
        }
        // Pad the trailing partial week.
        while cells.count % 7 != 0 {
            cells.append(MonthDay(dayNumber: "", isInMonth: false, isToday: false, hasRenewal: false))
        }
        return cells
    }

    /// One total per currency, joined as "$29.98 + ₺10,99". Mixed currencies
    /// are never added into one number (roadmap §8.6 "Honest aggregation");
    /// the most-used currency in the window comes first.
    private func currencyTotalsText(for subs: [Subscription]) -> String? {
        let parts = Dictionary(grouping: subs, by: \.currencyCode)
            .map { code, group in
                (code: code, count: group.count, total: group.reduce(Decimal(0)) { $0 + $1.amount })
            }
            .filter { $0.total > 0 }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.code < rhs.code
            }
            .map { currencyFormatter.string(from: $0.total, currencyCode: $0.code) }
        return parts.isEmpty ? nil : parts.joined(separator: " + ")
    }

    /// Renewals inside the displayed month keyed by day number, soonest first.
    private func makeMonthPayments(
        _ subs: [Subscription],
        calendar: Calendar,
        monthDate: Date
    ) -> [MonthPayments] {
        guard let month = calendar.dateInterval(of: .month, for: monthDate) else { return [] }
        let inMonth = subs.filter { month.contains($0.nextRenewalDate) }
        let grouped = Dictionary(grouping: inMonth) { calendar.component(.day, from: $0.nextRenewalDate) }
        return grouped.keys.sorted().map { day in
            let rows = grouped[day, default: []]
                .sorted { $0.amount > $1.amount }
                .map { sub in
                    RenewalRow(
                        subscription: sub,
                        name: sub.name,
                        categoryName: categoryLine(for: sub),
                        amountText: currencyFormatter.string(from: sub.amount, currencyCode: sub.currencyCode)
                    )
                }
            return MonthPayments(dayNumber: "\(day)", rows: rows)
        }
    }

    /// Sum of renewals dated inside the current month, one total per currency.
    private func dueThisMonth(_ subs: [Subscription], calendar: Calendar, now: Date) -> String? {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return nil }
        return currencyTotalsText(for: subs.filter { month.contains($0.nextRenewalDate) })
    }

    private func makeWeek(_ subs: [Subscription], calendar: Calendar, now: Date) -> [WeekDay] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let letterFormatter = DateFormatter()
        letterFormatter.calendar = calendar
        letterFormatter.setLocalizedDateFormatFromTemplate("EEEEE")

        let renewalDays = Set(subs.map { calendar.startOfDay(for: $0.nextRenewalDate) })
        let today = calendar.startOfDay(for: now)

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let start = calendar.startOfDay(for: day)
            return WeekDay(
                weekdayLetter: letterFormatter.string(from: day).uppercased(),
                dayNumber: "\(calendar.component(.day, from: day))",
                isToday: start == today,
                renewalCount: renewalDays.contains(start) ? 1 : 0
            )
        }
    }

    /// Renewals in the next 30 days, grouped by day, soonest first.
    private func makeGroups(_ subs: [Subscription], calendar: Calendar, now: Date) -> [DayGroup] {
        let today = calendar.startOfDay(for: now)
        guard let horizon = calendar.date(byAdding: .day, value: 30, to: today) else { return [] }

        let upcoming = subs.filter { $0.nextRenewalDate >= today && $0.nextRenewalDate < horizon }
        let grouped = Dictionary(grouping: upcoming) { calendar.startOfDay(for: $0.nextRenewalDate) }

        return grouped.keys.sorted().map { day in
            let rows = grouped[day, default: []]
                .sorted { $0.amount > $1.amount }
                .map { sub in
                    RenewalRow(
                        subscription: sub,
                        name: sub.name,
                        categoryName: categoryLine(for: sub),
                        amountText: currencyFormatter.string(from: sub.amount, currencyCode: sub.currencyCode)
                    )
                }
            return DayGroup(title: dayTitleFormatter.string(from: day), rows: rows)
        }
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        formatter.calendar = dateProvider.calendar
        return formatter
    }

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        formatter.calendar = dateProvider.calendar
        return formatter
    }

    private var dayTitleFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        formatter.calendar = dateProvider.calendar
        return formatter
    }

    /// "Streaming, Music" — every tag joined; nil when uncategorized.
    private func categoryLine(for subscription: Subscription) -> String? {
        let names = subscription.categoryIDs.compactMap { categoriesByID[$0]?.localizedName }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }
}
