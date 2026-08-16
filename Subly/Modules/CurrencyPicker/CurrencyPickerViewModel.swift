import Foundation

@MainActor
final class CurrencyPickerViewModel {

    struct Row: Hashable, Sendable {
        let currency: Currency
        let title: String
        let detail: String     // localized name
        let isSelected: Bool
    }

    struct Section: Hashable, Sendable {
        enum Kind: Hashable, Sendable {
            case suggested
            case all
        }
        let kind: Kind
        let title: String
        let rows: [Row]
    }

    struct Snapshot: Hashable, Sendable {
        let sections: [Section]
        let isEmpty: Bool
    }

    private let currencyManager: CurrencyManaging
    private let initiallySelectedCode: String

    private var query: String = ""
    private var observationTask: Task<Void, Never>?

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onSelect: ((String) -> Void)?

    init(
        currencyManager: CurrencyManaging,
        initiallySelectedCode: String
    ) {
        self.currencyManager = currencyManager
        self.initiallySelectedCode = initiallySelectedCode
    }

    deinit {
        observationTask?.cancel()
    }

    func start() {
        publish()
    }

    func updateQuery(_ value: String) {
        query = value
        publish()
    }

    func select(_ code: String) {
        onSelect?(code)
    }

    // MARK: - Snapshot

    private func publish() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = currencyManager.supported
        let preferred = currencyManager.preferredDisplayCurrency
        let deviceCode = Locale.current.currency?.identifier
        let device = deviceCode.flatMap { currencyManager.currency(for: $0) }

        var suggested: [Currency] = [preferred]
        if let device, device.code != preferred.code {
            suggested.append(device)
        }
        if !suggested.contains(where: { $0.code == initiallySelectedCode }),
           let active = currencyManager.currency(for: initiallySelectedCode) {
            suggested.append(active)
        }

        let suggestedRows = suggested
            .filter { matches(currency: $0, trimmedQuery: trimmed) }
            .map { row(for: $0) }

        let allRows = all
            .filter { matches(currency: $0, trimmedQuery: trimmed) }
            .sorted { lhs, rhs in
                lhs.code.localizedCompare(rhs.code) == .orderedAscending
            }
            .map { row(for: $0) }

        var sections: [Section] = []
        if !suggestedRows.isEmpty {
            sections.append(Section(
                kind: .suggested,
                title: Strings.Currency.sectionSuggested,
                rows: suggestedRows
            ))
        }
        if !allRows.isEmpty {
            sections.append(Section(
                kind: .all,
                title: Strings.Currency.sectionAll,
                rows: allRows
            ))
        }
        state = .loaded(Snapshot(sections: sections, isEmpty: sections.isEmpty))
    }

    private func matches(currency: Currency, trimmedQuery: String) -> Bool {
        guard !trimmedQuery.isEmpty else { return true }
        if currency.code.lowercased().contains(trimmedQuery) { return true }
        if currency.symbol.lowercased().contains(trimmedQuery) { return true }
        if L(currency.displayNameKey).lowercased().contains(trimmedQuery) { return true }
        return false
    }

    private func row(for currency: Currency) -> Row {
        Row(
            currency: currency,
            title: "\(currency.code)  \(currency.symbol)",
            detail: L(currency.displayNameKey),
            isSelected: currency.code == initiallySelectedCode
        )
    }
}
