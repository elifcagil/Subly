import UIKit

/// Read side of the recap feature for screens: what is available now and
/// which recap covers a month (for the Timeline archive).
protocol RecapAvailabilityProviding: Sendable {
    /// The newest recap that is due, unseen, and still inside its 7-day
    /// dashboard window — or nil.
    @MainActor func availableRecap() async -> Recap?
    /// Any due recap by index (past recaps stay reachable).
    @MainActor func recap(index: Int) async -> Recap?
    /// Latest due recap, regardless of seen state.
    @MainActor func latestDueRecap() async -> Recap?
    /// Header story icon: the latest recap inside its 7-day window and
    /// whether it was opened; nil → icon hidden.
    @MainActor func storyRecap() async -> (recap: Recap, state: RecapStoryState)?
    /// Index of the due recap whose period covers `date`.
    @MainActor func recapIndex(covering date: Date) -> Int?
    @MainActor func periodLabel(for recap: Recap) -> String
    @MainActor func markSeen(_ recap: Recap)
}

/// Owns the recap cadence (every 3 months from `registeredAt`), the "Your
/// recap is ready" notification and the seen-state (handoff:
/// `CLAUDE_CODE_PROMPT_RECAP.md`).
@MainActor
final class RecapScheduler: RecapAvailabilityProviding {

    static let dashboardWindowDays = 7

    private let deviceIdentity: DeviceIdentityProviding
    private let repository: SubscriptionRepository
    private let currencyManager: CurrencyManaging
    private let currencyFormatter: CurrencyFormatting
    private let notifications: ReminderScheduling
    private let builder: ReminderContentBuilder
    private let service: RecapService
    private let dateProvider: DateProviding
    private let defaults: UserDefaults
    private let logger: Logging
    private var timeChangeObserver: NSObjectProtocol?

    private let lastSeenKey = "com.subly.recap.last_seen_index"
    /// Cadence anchor: the day the first subscription was added (falls back
    /// to the device registration date). Refreshed by every async call so the
    /// synchronous `recapIndex(covering:)` can use it.
    private var cachedAnchor: Date?

    init(
        deviceIdentity: DeviceIdentityProviding,
        repository: SubscriptionRepository,
        currencyManager: CurrencyManaging,
        currencyFormatter: CurrencyFormatting,
        notifications: ReminderScheduling,
        builder: ReminderContentBuilder,
        dateProvider: DateProviding,
        defaults: UserDefaults = .standard,
        logger: Logging
    ) {
        self.deviceIdentity = deviceIdentity
        self.repository = repository
        self.currencyManager = currencyManager
        self.currencyFormatter = currencyFormatter
        self.notifications = notifications
        self.builder = builder
        self.service = RecapService(calendar: dateProvider.calendar)
        self.dateProvider = dateProvider
        self.defaults = defaults
        self.logger = logger
    }

    deinit {
        if let timeChangeObserver { NotificationCenter.default.removeObserver(timeChangeObserver) }
    }

    private var cadence: RecapCadence? {
        (cachedAnchor ?? deviceIdentity.registeredAt()).map { RecapCadence(registeredAt: $0, calendar: dateProvider.calendar) }
    }

    /// The first recap comes 3 months after the **first subscription** was
    /// added; later ones every 3 months from there.
    private func refreshAnchor() async {
        let subscriptions = (try? await repository.fetchAll()) ?? []
        let firstAdded = subscriptions.compactMap(\.createdAt).min()
        cachedAnchor = firstAdded.map { dateProvider.calendar.startOfDay(for: $0) } ?? deviceIdentity.registeredAt()
    }

    private(set) var lastSeenIndex: Int {
        get { defaults.integer(forKey: lastSeenKey) }
        set { defaults.set(newValue, forKey: lastSeenKey) }
    }

    // MARK: - Availability

    func availableRecap() async -> Recap? {
        await refreshAnchor()
        guard let cadence else { return nil }
        let now = dateProvider.now
        let latest = cadence.latestDueIndex(at: now)
        guard latest >= 1, latest > lastSeenIndex else { return nil }
        let windowEnd = dateProvider.calendar.date(
            byAdding: .day, value: Self.dashboardWindowDays, to: cadence.recapDate(latest)
        ) ?? now
        guard now < windowEnd else { return nil }
        return await recap(index: latest)
    }

    func storyRecap() async -> (recap: Recap, state: RecapStoryState)? {
        await refreshAnchor()
        guard let cadence else { return nil }
        let now = dateProvider.now
        let latest = cadence.latestDueIndex(at: now)
        guard let state = RecapStoryState.resolve(
            latestDueIndex: latest, recapDate: cadence.recapDate(latest),
            lastSeenIndex: lastSeenIndex, now: now, calendar: dateProvider.calendar
        ), let recap = await recap(index: latest) else { return nil }
        return (recap, state)
    }

    func latestDueRecap() async -> Recap? {
        await refreshAnchor()
        guard let cadence else { return nil }
        let latest = cadence.latestDueIndex(at: dateProvider.now)
        guard latest >= 1 else { return nil }
        return await recap(index: latest)
    }

    func recap(index: Int) async -> Recap? {
        if cachedAnchor == nil { await refreshAnchor() }
        guard let cadence, index >= 1, index <= cadence.latestDueIndex(at: dateProvider.now) else { return nil }
        let subscriptions = (try? await repository.fetchAll()) ?? []
        return service.recap(
            index: index,
            period: cadence.period(index),
            previousPeriod: index > 1 ? cadence.period(index - 1) : nil,
            subscriptions: subscriptions,
            preferredCurrencyCode: currencyManager.preferredDisplayCurrency.code,
            now: dateProvider.now
        )
    }

    /// When the next recap arrives (What's New finale: "Your first recap
    /// arrives on …"). Nil before the device has an anchor.
    func nextRecapDate() async -> Date? {
        await refreshAnchor()
        return cadence?.nextRecapDate(after: dateProvider.now)
    }

    func recapIndex(covering date: Date) -> Int? {
        cadence?.dueIndex(covering: date, at: dateProvider.now)
    }

    func periodLabel(for recap: Recap) -> String {
        RecapPeriodFormatter(calendar: dateProvider.calendar).label(for: recap.period)
    }

    func markSeen(_ recap: Recap) {
        if recap.index > lastSeenIndex { lastSeenIndex = recap.index }
    }

    // MARK: - Notification

    func startObservingTimeChanges() {
        guard timeChangeObserver == nil else { return }
        timeChangeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }

    /// Schedules "Your recap is ready" for 09:00 (quiet-hours aware) on the
    /// next recap date. Called on launch/foreground and time changes; the
    /// previous request is replaced so there is never more than one.
    func refresh() async {
        await notifications.removeAll(withPrefix: ReminderIdentifierPrefix.recap)
        await refreshAnchor()
        guard let cadence else { return }
        let now = dateProvider.now
        let nextIndex = cadence.latestDueIndex(at: now) + 1
        let nextDate = cadence.recapDate(nextIndex)
        let fireDate = builder.deliveryDate(on: nextDate)
        guard fireDate > now else { return }

        // Body previews the period that ends on that date, from today's data.
        let subscriptions = (try? await repository.fetchAll()) ?? []
        let preview = service.recap(
            index: nextIndex,
            period: cadence.period(nextIndex),
            previousPeriod: nil,
            subscriptions: subscriptions,
            preferredCurrencyCode: currencyManager.preferredDisplayCurrency.code,
            now: nextDate
        )
        guard let preview else { return }  // Nothing to recap → no notification.

        let request = ReminderRequest(
            identifier: "\(ReminderIdentifierPrefix.recap)\(NotificationIdentifierFormatter.dayKey(for: nextDate, calendar: dateProvider.calendar))",
            kind: .recap,
            title: Strings.Recap.notificationTitle,
            body: Strings.Recap.notificationBody(
                total: currencyFormatter.string(from: preview.total, currencyCode: preview.currencyCode),
                count: preview.subscriptionCount
            ),
            fireDate: fireDate,
            categoryIdentifier: ReminderCategory.recap,
            deliveryStyle: QuietHoursStore().current().deliveryStyle(for: fireDate, isSameDay: false, calendar: dateProvider.calendar),
            userInfo: ["recapIndex": "\(nextIndex)"]
        )
        await notifications.add(request)
        logger.debug("Recap #\(nextIndex) notification scheduled for \(fireDate).", category: "recap")
    }
}

/// "July–September", or "November 2026–January 2027" across a year.
struct RecapPeriodFormatter {
    let calendar: Calendar
    var locale: Locale = .current

    func label(for period: DateInterval) -> String {
        // Three month slices: the last one starts a month before `end`, so the
        // label matches the bars (14 Mar–14 Jun → "Mar–May").
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: period.end) ?? period.end
        let startYear = calendar.component(.year, from: period.start)
        let endYear = calendar.component(.year, from: lastMonth)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(startYear == endYear ? "MMMM" : "MMMMyyyy")
        return "\(formatter.string(from: period.start))–\(formatter.string(from: lastMonth))"
    }
}
