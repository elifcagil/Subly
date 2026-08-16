import Foundation

struct RenewalDateCalculator {

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func nextRenewalDate(after date: Date, cycle: BillingCycle) -> Date {
        let component: Calendar.Component
        let value: Int
        switch cycle {
        case .weekly:
            component = .day; value = 7
        case .monthly:
            component = .month; value = 1
        case .quarterly:
            component = .month; value = 3
        case .yearly:
            component = .year; value = 1
        case .custom:
            component = .month; value = 1
        }
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }

    func upcomingRenewalDate(from startDate: Date, cycle: BillingCycle, relativeTo reference: Date) -> Date {
        var date = startDate
        while date < reference {
            date = nextRenewalDate(after: date, cycle: cycle)
        }
        return date
    }
}
