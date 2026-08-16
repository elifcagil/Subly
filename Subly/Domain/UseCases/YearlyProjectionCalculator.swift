import Foundation

struct YearlyProjectionCalculator {

    private let monthlyCalculator = MonthlySpendCalculator()

    func callAsFunction(_ subscriptions: [Subscription]) -> Decimal {
        monthlyCalculator(subscriptions) * Decimal(12)
    }
}
