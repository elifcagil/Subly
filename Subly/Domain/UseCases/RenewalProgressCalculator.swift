import Foundation

/// How far a subscription is through its current billing cycle — the value
/// the home screen widget's ring fills to (handoff: `CLAUDE_CODE_PROMPT_WIDGETS.md`).
///
/// `progress = clamp((cycleDays − daysLeft) / cycleDays, 0.02, 1)`: nearly
/// empty right after a renewal, full on renewal day.
struct RenewalProgressCalculator: Sendable {

    struct Progress: Hashable, Sendable {
        /// Calendar days from today to the renewal (0 = today).
        let daysLeft: Int
        /// Length of the current billing period in days.
        let cycleDays: Int
        /// 0.02 … 1.
        let fraction: Double
    }

    static let minimumFraction = 0.02

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func progress(for subscription: Subscription, on date: Date) -> Progress {
        progress(renewalDate: subscription.nextRenewalDate, cycle: subscription.billingCycle, on: date)
    }

    func progress(renewalDate: Date, cycle: BillingCycle, on date: Date) -> Progress {
        let today = calendar.startOfDay(for: date)
        let renewalDay = calendar.startOfDay(for: renewalDate)
        let daysLeft = max(0, calendar.dateComponents([.day], from: today, to: renewalDay).day ?? 0)
        let cycleDays = max(1, cycleLength(endingOn: renewalDay, cycle: cycle))
        let raw = Double(cycleDays - min(daysLeft, cycleDays)) / Double(cycleDays)
        return Progress(
            daysLeft: daysLeft,
            cycleDays: cycleDays,
            fraction: min(1, max(Self.minimumFraction, raw))
        )
    }

    /// Days in the period that ends on `renewalDay`: monthly = the actual
    /// month length (28–31), yearly = 365/366, weekly = 7, custom = monthly.
    func cycleLength(endingOn renewalDay: Date, cycle: BillingCycle) -> Int {
        let component: Calendar.Component
        let value: Int
        switch cycle {
        case .weekly: return 7
        case .monthly, .custom: component = .month; value = -1
        case .quarterly: component = .month; value = -3
        case .yearly: component = .year; value = -1
        }
        guard let start = calendar.date(byAdding: component, value: value, to: renewalDay) else { return 30 }
        return calendar.dateComponents([.day], from: start, to: renewalDay).day ?? 30
    }
}
