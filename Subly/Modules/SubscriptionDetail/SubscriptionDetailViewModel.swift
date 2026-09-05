import Foundation

/// v5 Detail (screen 04): centered tile header, accent hero card (next
/// renewal + amount), "Paid so far" card with payment-history bars,
/// settings-style rows (Remind me, Notes), Archive/Delete actions.
@MainActor
final class SubscriptionDetailViewModel {

    struct PaidSoFar: Hashable {
        let totalText: String
        let paymentCount: Int
        /// "5 payments since Mar 2026"
        let captionText: String
        /// Normalized bar values, oldest → newest (max 12).
        let bars: [Double]
    }

    struct Snapshot: Hashable {
        let title: String
        /// "Streaming · Monthly"
        let categoryLine: String
        /// Hero left value: "Tomorrow, July 4".
        let renewalText: String
        /// Hero right value.
        let amountText: String
        let paidSoFar: PaidSoFar?
        /// Current reminder summary ("1 day before" / "Off").
        let reminderValue: String
        let notes: String?
        let isArchived: Bool
    }

    private let subscriptionID: UUID
    private let subscriptionRepository: SubscriptionRepository
    private let categoryRepository: CategoryRepository
    private let notificationScheduler: NotificationScheduling
    private let currencyFormatter: CurrencyFormatting
    private let dateProvider: DateProviding
    private let preferences: SettingsPreferencesManaging

    private(set) var subscription: Subscription
    private var categoriesByID: [UUID: Category] = [:]

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onEditRequested: ((Subscription) -> Void)?
    var onDeleteRequested: (() -> Void)?
    /// Asks the coordinator to present the reminder sheet (screen 13) with the
    /// current lead-day selection.
    var onReminderSheetRequested: ((Int?) -> Void)?
    var onDismiss: (() -> Void)?

    init(
        subscription: Subscription,
        subscriptionRepository: SubscriptionRepository,
        categoryRepository: CategoryRepository,
        notificationScheduler: NotificationScheduling,
        currencyFormatter: CurrencyFormatting,
        dateProvider: DateProviding,
        preferences: SettingsPreferencesManaging
    ) {
        self.subscriptionID = subscription.id
        self.subscription = subscription
        self.subscriptionRepository = subscriptionRepository
        self.categoryRepository = categoryRepository
        self.notificationScheduler = notificationScheduler
        self.currencyFormatter = currencyFormatter
        self.dateProvider = dateProvider
        self.preferences = preferences
    }

    func load() {
        state = .loading
        Task { [weak self] in
            guard let self else { return }
            do {
                let categories = try await categoryRepository.fetchAll()
                self.categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            } catch {
                self.categoriesByID = [:]
            }
            await self.refreshSubscription()
        }
    }

    func reload() {
        Task { [weak self] in await self?.refreshSubscription() }
    }

    // MARK: - Intents

    func didTapEdit() {
        onEditRequested?(subscription)
    }

    func didTapDelete() {
        onDeleteRequested?()
    }

    func didTapReminder() {
        onReminderSheetRequested?(subscription.reminderLeadDays.min())
    }

    /// Persists a new reminder offset (nil = off) and reschedules locally.
    func setReminder(leadDays: Int?) {
        Task { [weak self] in
            guard let self else { return }
            var updated = subscription
            updated.reminderLeadDays = leadDays.map { [$0] } ?? []
            do {
                try await subscriptionRepository.save(updated)
                await notificationScheduler.cancel(for: updated.id)
                // Master notifications switch (Settings) gates scheduling.
                if let lead = leadDays, preferences.current().remindersEnabled {
                    try? await notificationScheduler.schedule(for: updated, leadDays: [lead])
                }
                self.subscription = updated
                self.publishSnapshot()
            } catch let error as UserFacingError {
                self.state = .failed(message: error.userMessage)
            } catch {
                self.state = .failed(message: Strings.Common.somethingWentWrong)
            }
        }
    }

    func toggleArchive() {
        Task { [weak self] in
            guard let self else { return }
            do {
                if subscription.isArchived {
                    var restored = subscription
                    restored.isArchived = false
                    try await subscriptionRepository.save(restored)
                    self.subscription = restored
                    self.publishSnapshot()
                } else {
                    try await subscriptionRepository.archive(subscription.id)
                    await notificationScheduler.cancel(for: subscription.id)
                    self.onDismiss?()
                }
            } catch {
                self.state = .failed(message: Strings.Common.somethingWentWrong)
            }
        }
    }

    func confirmDelete() {
        let id = subscriptionID
        Task { [weak self] in
            guard let self else { return }
            do {
                try await subscriptionRepository.delete(id)
                await notificationScheduler.cancel(for: id)
                self.onDismiss?()
            } catch let error as UserFacingError {
                self.state = .failed(message: error.userMessage)
            } catch {
                self.state = .failed(message: Strings.Common.somethingWentWrong)
            }
        }
    }

    // MARK: - Snapshot

    private func refreshSubscription() async {
        do {
            let fresh = try await subscriptionRepository.subscription(with: subscriptionID)
            subscription = fresh
            publishSnapshot()
        } catch {
            publishSnapshot()
        }
    }

    private func publishSnapshot() {
        let categoryNames = subscription.categoryIDs.compactMap { categoriesByID[$0]?.localizedName }
        let categoryName: String? = categoryNames.isEmpty ? nil : categoryNames.joined(separator: ", ")
        let categoryLine = [categoryName, subscription.billingCycle.localizedName]
            .compactMap { $0 }
            .joined(separator: " · ")

        state = .loaded(Snapshot(
            title: subscription.name,
            categoryLine: categoryLine,
            renewalText: renewalText(),
            amountText: currencyFormatter.string(from: subscription.amount, currencyCode: subscription.currencyCode),
            paidSoFar: makePaidSoFar(),
            reminderValue: reminderValue(),
            notes: subscription.notes,
            isArchived: subscription.isArchived
        ))
    }

    /// "Tomorrow, July 4" / "Today, July 3" / "In 5 days, July 8".
    private func renewalText() -> String {
        let calendar = dateProvider.calendar
        let date = subscription.nextRenewalDate
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: dateProvider.now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        let dateText = renewalDateFormatter.string(from: date)
        switch days {
        case ..<0: return dateText
        case 0: return "\(Strings.SubscriptionDetail.dueToday), \(dateText)"
        case 1: return "\(Strings.SubscriptionDetail.dueTomorrow), \(dateText)"
        default: return "\(String(format: Strings.SubscriptionDetail.inDaysFormat, days)), \(dateText)"
        }
    }

    /// Payments made since `startDate`, derived from the billing cycle. v1
    /// stores no payment history, so this is an honest projection: count of
    /// elapsed cycles × current price. Bars are uniform (price is constant).
    private func makePaidSoFar() -> PaidSoFar? {
        guard let step = cycleStep() else { return nil }
        let calendar = dateProvider.calendar
        let now = dateProvider.now
        guard subscription.startDate <= now else { return nil }

        var count = 0
        var cursor = subscription.startDate
        while cursor <= now && count < 600 {
            count += 1
            guard let next = calendar.date(byAdding: step.component, value: step.value, to: cursor) else { break }
            cursor = next
        }
        guard count > 0 else { return nil }

        let total = subscription.amount * Decimal(count)
        let sinceText = sinceFormatter.string(from: subscription.startDate)
        let caption = count == 1
            ? String(format: Strings.SubscriptionDetail.paymentSinceSingularFormat, sinceText)
            : String(format: Strings.SubscriptionDetail.paymentsSinceFormat, count, sinceText)
        return PaidSoFar(
            totalText: currencyFormatter.string(from: total, currencyCode: subscription.currencyCode),
            paymentCount: count,
            captionText: caption,
            bars: Array(repeating: 1.0, count: min(count, 12))
        )
    }

    private func cycleStep() -> (component: Calendar.Component, value: Int)? {
        switch subscription.billingCycle {
        case .weekly: return (.weekOfYear, 1)
        case .monthly: return (.month, 1)
        case .quarterly: return (.month, 3)
        case .yearly: return (.year, 1)
        case .custom: return nil
        }
    }

    private func reminderValue() -> String {
        guard let lead = subscription.reminderLeadDays.min() else {
            return Strings.Settings.remindersOff
        }
        switch lead {
        case 0: return Strings.Settings.remindersSameDay
        case 1: return Strings.Settings.remindersOneDay
        case 7: return Strings.SubscriptionDetail.oneWeekBefore
        default: return String(format: Strings.Settings.remindersDaysFormat, lead)
        }
    }

    private var renewalDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM d")
        formatter.calendar = dateProvider.calendar
        return formatter
    }

    private var sinceFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        formatter.calendar = dateProvider.calendar
        return formatter
    }
}
