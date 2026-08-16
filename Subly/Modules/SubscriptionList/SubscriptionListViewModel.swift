import Foundation

@MainActor
final class SubscriptionListViewModel {

    enum SortOrder: Hashable, Sendable {
        case renewalDate
        case amount
        case name
        case recentlyAdded
    }

    enum ArchivedFilter: Hashable, Sendable {
        case active
        case archived
    }

    struct FilterChip: Hashable, Sendable {
        let id: UUID?
        let title: String
        let isSelected: Bool
        let isAllChip: Bool
    }

    struct Row: Hashable {
        let subscription: Subscription
        let primaryText: String
        /// v5 meta: "Category · Jul 2".
        let secondaryText: String
        let amountText: String
        /// Lowercased cycle sub-label under the price ("monthly").
        let cycleText: String
        let avatarSystemIcon: String
        let categoryName: String?
    }

    struct Section: Hashable {
        let title: String
        let rows: [Row]
    }

    struct Snapshot: Hashable {
        let sections: [Section]
        let categoryChips: [FilterChip]
        let archivedFilter: ArchivedFilter
        let sortOrder: SortOrder
        let hasFiltersApplied: Bool
    }

    private let subscriptionRepository: SubscriptionRepository
    private let categoryRepository: CategoryRepository
    private let currencyFormatter: CurrencyFormatting
    private let dateProvider: DateProviding
    private var observationTask: Task<Void, Never>?
    private var categoriesByID: [UUID: Category] = [:]
    private var orderedCategories: [Category] = []
    private var latestItems: [Subscription] = []

    private var query: String = ""
    private var selectedCategoryID: UUID? = nil
    private(set) var archivedFilter: ArchivedFilter = .active
    private(set) var sortOrder: SortOrder = .renewalDate

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onSelectSubscription: ((Subscription) -> Void)?
    var onEditSubscription: ((Subscription) -> Void)?
    var onDeleteSubscription: ((Subscription) -> Void)?
    var onArchivedSubscription: (() -> Void)?

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
        Task { [weak self] in
            guard let self else { return }
            do {
                let categories = try await categoryRepository.fetchAll()
                self.orderedCategories = categories
                self.categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            } catch {
                self.categoriesByID = [:]
            }
            self.beginObserving()
        }
    }

    // MARK: - Intents

    func updateQuery(_ value: String) {
        query = value
        republish()
    }

    func selectCategory(_ id: UUID?) {
        selectedCategoryID = id
        republish()
    }

    func setArchivedFilter(_ filter: ArchivedFilter) {
        archivedFilter = filter
        republish()
    }

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        republish()
    }

    func didSelectSubscription(_ subscription: Subscription) {
        onSelectSubscription?(subscription)
    }

    func didRequestEdit(_ subscription: Subscription) {
        onEditSubscription?(subscription)
    }

    func didRequestDelete(_ subscription: Subscription) {
        onDeleteSubscription?(subscription)
    }

    func delete(_ subscription: Subscription) {
        Task { [weak self] in
            guard let self else { return }
            try? await subscriptionRepository.delete(subscription.id)
        }
    }

    func archive(_ subscription: Subscription) {
        Task { [weak self] in
            guard let self else { return }
            try? await subscriptionRepository.archive(subscription.id)
            self.onArchivedSubscription?()
        }
    }

    func restore(_ subscription: Subscription) {
        Task { [weak self] in
            guard let self else { return }
            var restored = subscription
            restored.isArchived = false
            try? await subscriptionRepository.save(restored)
        }
    }

    // MARK: - Observation

    private func beginObserving() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            let stream = subscriptionRepository.observe()
            for await items in stream {
                if Task.isCancelled { return }
                self.latestItems = items
                self.republish()
            }
        }
    }

    private func republish() {
        publish(items: latestItems)
    }

    // MARK: - Snapshot

    private func publish(items: [Subscription]) {
        let scoped = items.filter { matchesArchivedFilter($0) }
        let categoryFiltered = scoped.filter { matchesCategory($0) }
        let searched = categoryFiltered.filter { matchesQuery($0) }

        guard !searched.isEmpty else {
            let snapshot = Snapshot(
                sections: [],
                categoryChips: makeCategoryChips(),
                archivedFilter: archivedFilter,
                sortOrder: sortOrder,
                hasFiltersApplied: hasFiltersApplied
            )
            if items.isEmpty {
                state = .empty
            } else {
                state = .loaded(snapshot)
            }
            return
        }

        // v5 (screen 03): one flat group — the category lives in each row's
        // meta line ("Streaming · Jul 2"), not in section headers.
        let sections = [Section(
            title: "",
            rows: sortRows(searched).map { row(for: $0) }
        )]
        state = .loaded(Snapshot(
            sections: sections,
            categoryChips: makeCategoryChips(),
            archivedFilter: archivedFilter,
            sortOrder: sortOrder,
            hasFiltersApplied: hasFiltersApplied
        ))
    }

    private func matchesArchivedFilter(_ subscription: Subscription) -> Bool {
        switch archivedFilter {
        case .active: return !subscription.isArchived
        case .archived: return subscription.isArchived
        }
    }

    private func matchesCategory(_ subscription: Subscription) -> Bool {
        guard let selected = selectedCategoryID else { return true }
        return subscription.categoryID == selected
    }

    private func matchesQuery(_ subscription: Subscription) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }
        if subscription.name.lowercased().contains(trimmed) { return true }
        if let notes = subscription.notes, notes.lowercased().contains(trimmed) { return true }
        if let cat = subscription.categoryID.flatMap({ categoriesByID[$0] }),
           cat.localizedName.lowercased().contains(trimmed) { return true }
        return false
    }

    private func sortRows(_ rows: [Subscription]) -> [Subscription] {
        switch sortOrder {
        case .renewalDate:
            return rows.sorted { $0.nextRenewalDate < $1.nextRenewalDate }
        case .amount:
            return rows.sorted { $0.amount > $1.amount }
        case .name:
            return rows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recentlyAdded:
            return rows.sorted { $0.startDate > $1.startDate }
        }
    }

    private var hasFiltersApplied: Bool {
        selectedCategoryID != nil
            || archivedFilter != .active
            || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func makeCategoryChips() -> [FilterChip] {
        var chips: [FilterChip] = []
        chips.append(FilterChip(
            id: nil,
            title: Strings.List.filterAll,
            isSelected: selectedCategoryID == nil,
            isAllChip: true
        ))
        for category in orderedCategories {
            chips.append(FilterChip(
                id: category.id,
                title: category.localizedName,
                isSelected: selectedCategoryID == category.id,
                isAllChip: false
            ))
        }
        return chips
    }

    private func sectionTitle(for categoryID: UUID?) -> String {
        guard let id = categoryID, let category = categoriesByID[id] else {
            return Strings.SubscriptionList.uncategorized
        }
        return category.localizedName
    }

    private func row(for subscription: Subscription) -> Row {
        let amount = currencyFormatter.string(from: subscription.amount, currencyCode: subscription.currencyCode)
        let dateText = dateFormatter.string(from: subscription.nextRenewalDate)
        let category = subscription.categoryID.flatMap { categoriesByID[$0] }
        let categoryName = category?.localizedName ?? Strings.SubscriptionList.uncategorized
        return Row(
            subscription: subscription,
            primaryText: subscription.name,
            secondaryText: "\(categoryName) · \(dateText)",
            amountText: amount,
            cycleText: subscription.billingCycle.localizedName.lowercased(),
            avatarSystemIcon: category?.systemIconName ?? "creditcard",
            categoryName: category?.localizedName
        )
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d") // "Jul 2"
        formatter.calendar = dateProvider.calendar
        return formatter
    }
}
