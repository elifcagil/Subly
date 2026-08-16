import Foundation

struct MonthlySpendCalculator {

    func callAsFunction(_ subscriptions: [Subscription]) -> Decimal {
        subscriptions
            .filter { !$0.isArchived }
            .reduce(Decimal(0)) { partial, subscription in
                partial + monthlyEquivalent(of: subscription)
            }
    }

    func monthlyEquivalent(of subscription: Subscription) -> Decimal {
        switch subscription.billingCycle {
        case .weekly: return subscription.amount * Decimal(52) / Decimal(12)
        case .monthly: return subscription.amount
        case .quarterly: return subscription.amount / Decimal(3)
        case .yearly: return subscription.amount / Decimal(12)
        case .custom: return subscription.amount
        }
    }
}
