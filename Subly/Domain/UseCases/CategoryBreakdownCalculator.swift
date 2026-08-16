import Foundation

struct CategoryBreakdownCalculator {

    struct Result: Hashable {
        let categoryID: UUID?
        let total: Decimal
        let share: Double
    }

    private let monthlyCalculator = MonthlySpendCalculator()

    func callAsFunction(_ subscriptions: [Subscription]) -> [Result] {
        let active = subscriptions.filter { !$0.isArchived }
        guard !active.isEmpty else { return [] }

        let grouped = Dictionary(grouping: active) { $0.categoryID }
        let monthlyTotals: [UUID?: Decimal] = grouped.mapValues { items in
            items.reduce(Decimal(0)) { $0 + monthlyCalculator.monthlyEquivalent(of: $1) }
        }

        let overall = monthlyTotals.values.reduce(Decimal(0), +)
        let denominator = NSDecimalNumber(decimal: overall).doubleValue

        guard denominator > 0 else { return [] }

        return monthlyTotals
            .map { key, value in
                Result(
                    categoryID: key,
                    total: value,
                    share: NSDecimalNumber(decimal: value).doubleValue / denominator
                )
            }
            .sorted { $0.total > $1.total }
    }
}
