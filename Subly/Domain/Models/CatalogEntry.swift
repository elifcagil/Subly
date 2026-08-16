import Foundation

struct CatalogEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let suggestedAmount: Decimal
    let currencyCode: String
    let billingCycle: BillingCycle
    let categoryName: String
    let systemIcon: String
    let searchTerms: [String]

    init(
        id: UUID = UUID(),
        name: String,
        suggestedAmount: Decimal,
        currencyCode: String = "USD",
        billingCycle: BillingCycle = .monthly,
        categoryName: String,
        systemIcon: String,
        searchTerms: [String] = []
    ) {
        self.id = id
        self.name = name
        self.suggestedAmount = suggestedAmount
        self.currencyCode = currencyCode
        self.billingCycle = billingCycle
        self.categoryName = categoryName
        self.systemIcon = systemIcon
        self.searchTerms = searchTerms
    }

    func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        if name.lowercased().contains(needle) { return true }
        if categoryName.lowercased().contains(needle) { return true }
        return searchTerms.contains { $0.lowercased().contains(needle) }
    }
}
