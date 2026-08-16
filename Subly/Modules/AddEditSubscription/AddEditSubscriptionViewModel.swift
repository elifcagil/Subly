import Foundation

@MainActor
final class AddEditSubscriptionViewModel {

    enum Mode {
        case create
        case createFromCatalog(CatalogEntry)
        case edit(Subscription)
    }

    struct Snapshot: Equatable {
        let title: String
        let isSaveEnabled: Bool
        let isSaving: Bool
        let draft: SubscriptionDraft
        let categories: [Category]
        let availableLeadOptions: [Int]
        let currencyDisplay: String
        /// v5 live impact footer: "Adds $16.00/mo — your monthly total becomes
        /// $87.46". Nil until the draft amount parses.
        let impactText: String?
    }

    private let subscriptionRepository: SubscriptionRepository
    private let categoryRepository: CategoryRepository
    private let notificationScheduler: NotificationScheduling
    private let preferences: SettingsPreferencesManaging
    private let calendarService: CalendarService
    private let dateProvider: DateProviding
    private let currencyManager: CurrencyManaging
    private let currencyFormatter: CurrencyFormatting
    private let mode: Mode

    private(set) var draft: SubscriptionDraft
    private(set) var categories: [Category] = []
    private var isSaving: Bool = false
    /// Active subscriptions at load time — base for the live impact footer.
    private var existingSubscriptions: [Subscription] = []
    private let monthlyCalculator = MonthlySpendCalculator()

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onErrorMessage: ((String) -> Void)?
    var onSaved: (() -> Void)?
    var onCancelled: (() -> Void)?

    let availableLeadOptions: [Int] = [0, 1, 3, 7]

    init(
        mode: Mode,
        subscriptionRepository: SubscriptionRepository,
        categoryRepository: CategoryRepository,
        notificationScheduler: NotificationScheduling,
        preferences: SettingsPreferencesManaging,
        calendarService: CalendarService,
        currencyManager: CurrencyManaging,
        currencyFormatter: CurrencyFormatting,
        dateProvider: DateProviding,
        defaultCurrencyCode: String
    ) {
        self.mode = mode
        self.subscriptionRepository = subscriptionRepository
        self.categoryRepository = categoryRepository
        self.notificationScheduler = notificationScheduler
        self.preferences = preferences
        self.calendarService = calendarService
        self.currencyManager = currencyManager
        self.currencyFormatter = currencyFormatter
        self.dateProvider = dateProvider
        switch mode {
        case .create:
            self.draft = .new(
                currencyCode: defaultCurrencyCode,
                today: dateProvider.now,
                defaultReminderLeadDays: preferences.current().defaultReminderLeadDays
            )
        case .createFromCatalog(let entry):
            self.draft = .from(
                entry: entry,
                fallbackCurrency: defaultCurrencyCode,
                today: dateProvider.now,
                defaultReminderLeadDays: preferences.current().defaultReminderLeadDays
            )
        case .edit(let subscription):
            self.draft = .from(subscription)
        }
        // New subscriptions default the next renewal to one cycle from today
        // (monthly → +1 month, weekly → +1 week …); the user can still pick
        // any date from the calendar.
        if case .edit = mode {} else {
            draft.nextRenewalDate = defaultRenewalDate(for: draft.billingCycle)
        }
    }

    /// Whether the user picked a renewal date manually — once true, cycle
    /// changes stop moving the date.
    private var userPickedRenewalDate = false

    /// Today + one billing cycle (custom keeps today).
    private func defaultRenewalDate(for cycle: BillingCycle) -> Date {
        let calendar = dateProvider.calendar
        let now = dateProvider.now
        let step: (Calendar.Component, Int)?
        switch cycle {
        case .weekly: step = (.weekOfYear, 1)
        case .monthly: step = (.month, 1)
        case .quarterly: step = (.month, 3)
        case .yearly: step = (.year, 1)
        case .custom: step = nil
        }
        guard let (component, value) = step else { return now }
        return calendar.date(byAdding: component, value: value, to: now) ?? now
    }

    var title: String {
        switch mode {
        case .create, .createFromCatalog: return Strings.AddEdit.addTitle
        case .edit: return Strings.AddEdit.editTitle
        }
    }

    func load() {
        state = .loading
        Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await categoryRepository.fetchAll()
                self.categories = loaded
                self.existingSubscriptions = (try? await subscriptionRepository.fetchActive()) ?? []
                self.resolveCatalogCategoryIfNeeded()
                self.publishSnapshot()
            } catch {
                self.state = .failed(message: "We couldn't load categories.")
            }
        }
    }

    private func resolveCatalogCategoryIfNeeded() {
        guard case .createFromCatalog(let entry) = mode,
              draft.categoryID == nil,
              let match = categories.first(where: { $0.name.caseInsensitiveCompare(entry.categoryName) == .orderedSame }) else {
            return
        }
        draft.categoryID = match.id
    }

    func updateName(_ value: String) {
        draft.name = value
        publishSnapshot()
    }

    func updateAmount(_ value: String) {
        draft.amountText = value
        publishSnapshot()
    }

    func updateBillingCycle(_ value: BillingCycle) {
        draft.billingCycle = value
        // Follow the cycle with a matching default date until the user picks
        // one themselves (never stomp a manual choice).
        if case .edit = mode {} else if !userPickedRenewalDate {
            draft.nextRenewalDate = defaultRenewalDate(for: value)
        }
        publishSnapshot()
    }

    func updateNextRenewalDate(_ value: Date) {
        userPickedRenewalDate = true
        draft.nextRenewalDate = value
        publishSnapshot()
    }

    func updateCategory(_ value: UUID?) {
        draft.categoryID = value
        publishSnapshot()
    }

    func updateCurrencyCode(_ code: String) {
        draft.currencyCode = code
        publishSnapshot()
    }

    func updateNotes(_ value: String) {
        draft.notes = value
        publishSnapshot()
    }

    func toggleReminderLeadDay(_ value: Int) {
        if draft.reminderLeadDays.contains(value) {
            draft.reminderLeadDays.remove(value)
        } else {
            draft.reminderLeadDays.insert(value)
        }
        publishSnapshot()
    }

    func didTapCancel() {
        onCancelled?()
    }

    func didTapSave() {
        switch draft.validated() {
        case .failure(let validation):
            onErrorMessage?(validation.userMessage)
        case .success(let subscription):
            persist(subscription)
        }
    }

    private func persist(_ subscription: Subscription) {
        // Master notifications switch (Settings) gates all reminder scheduling.
        let leadDays = preferences.current().remindersEnabled
            ? subscription.reminderLeadDays
            : []
        isSaving = true
        publishSnapshot()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await subscriptionRepository.save(subscription)
                if !leadDays.isEmpty {
                    do {
                        try await notificationScheduler.schedule(for: subscription, leadDays: leadDays)
                    } catch {
                        // Scheduling errors do not block save; surface as a soft warning.
                    }
                } else {
                    await notificationScheduler.cancel(for: subscription.id)
                }
                if self.preferences.current().calendarExportEnabled {
                    _ = try? await self.calendarService.export(subscription)
                }
                self.isSaving = false
                self.onSaved?()
            } catch let error as UserFacingError {
                self.isSaving = false
                self.publishSnapshot()
                self.onErrorMessage?(error.userMessage)
            } catch {
                self.isSaving = false
                self.publishSnapshot()
                self.onErrorMessage?(Strings.Common.somethingWentWrong)
            }
        }
    }

    private func publishSnapshot() {
        let snapshot = Snapshot(
            title: title,
            isSaveEnabled: isValidPreview && !isSaving,
            isSaving: isSaving,
            draft: draft,
            categories: categories,
            availableLeadOptions: availableLeadOptions,
            currencyDisplay: currencyDisplay(for: draft.currencyCode),
            impactText: makeImpactText()
        )
        state = .loaded(snapshot)
    }

    /// Recomputes as price/cycle changes (v5 screen 08). Compares against the
    /// current active total in the draft's currency, excluding the edited
    /// subscription itself — never mixes currencies.
    private func makeImpactText() -> String? {
        guard let amount = Decimal(string: draft.amountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else { return nil }

        let probe = Subscription(
            id: draft.id,
            name: "probe",
            amount: amount,
            currencyCode: draft.currencyCode,
            billingCycle: draft.billingCycle,
            startDate: draft.startDate,
            nextRenewalDate: draft.nextRenewalDate
        )
        let draftMonthly = monthlyCalculator.monthlyEquivalent(of: probe)

        let baseTotal = existingSubscriptions
            .filter { $0.currencyCode == draft.currencyCode && $0.id != draft.id }
            .reduce(Decimal(0)) { $0 + monthlyCalculator.monthlyEquivalent(of: $1) }

        let addsText = currencyFormatterString(draftMonthly)
        let totalText = currencyFormatterString(baseTotal + draftMonthly)
        return String(format: Strings.AddEdit.impactFormat, addsText, totalText)
    }

    private func currencyFormatterString(_ value: Decimal) -> String {
        currencyFormatter.string(from: value, currencyCode: draft.currencyCode)
    }

    private func currencyDisplay(for code: String) -> String {
        guard let currency = currencyManager.currency(for: code) else { return code }
        return "\(currency.code)  \(currency.symbol)"
    }

    private var isValidPreview: Bool {
        switch draft.validated() {
        case .success: return true
        case .failure: return false
        }
    }
}
