import Foundation

/// Subly keeps no payment history; charges are projected from each
/// subscription's start date and billing cycle. Used by the recap to say
/// what a period cost.
struct PaymentProjector: Sendable {

    private let calendar: Calendar
    private let renewalCalculator: RenewalDateCalculator

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.renewalCalculator = RenewalDateCalculator(calendar: calendar)
    }

    /// Charge dates of `subscription` inside `interval` (start inclusive, end
    /// exclusive), never before the subscription started.
    func paymentDates(for subscription: Subscription, in interval: DateInterval) -> [Date] {
        var date = calendar.startOfDay(for: subscription.startDate)
        var dates: [Date] = []
        var steps = 0
        while date < interval.end && steps < 1200 {
            if date >= interval.start { dates.append(date) }
            let next = renewalCalculator.nextRenewalDate(after: date, cycle: subscription.billingCycle)
            guard next > date else { break }
            date = next
            steps += 1
        }
        return dates
    }

    func amountPaid(by subscription: Subscription, in interval: DateInterval) -> Decimal {
        subscription.amount * Decimal(paymentDates(for: subscription, in: interval).count)
    }

    /// Everything paid since the subscription started, up to `now`.
    func amountPaidToDate(by subscription: Subscription, now: Date) -> Decimal {
        let start = calendar.startOfDay(for: subscription.startDate)
        guard start <= now, let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return 0
        }
        return amountPaid(by: subscription, in: DateInterval(start: start, end: end))
    }
}
