import Foundation

struct UpcomingRenewalsUseCase {

    private let calendar: Calendar
    private let now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }

    func callAsFunction(_ subscriptions: [Subscription], withinDays days: Int) -> [Subscription] {
        let start = now()
        guard let end = calendar.date(byAdding: .day, value: days, to: start) else {
            return []
        }
        return subscriptions
            .filter { !$0.isArchived }
            .filter { $0.nextRenewalDate >= start && $0.nextRenewalDate <= end }
            .sorted { $0.nextRenewalDate < $1.nextRenewalDate }
    }
}
