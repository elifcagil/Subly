import Foundation

struct RenewalProjectionCalculator {

    struct WeekBucket: Hashable {
        let weekStart: Date
        let weekEnd: Date
        let total: Decimal
        let count: Int
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func callAsFunction(
        _ subscriptions: [Subscription],
        weeks: Int,
        relativeTo reference: Date
    ) -> [WeekBucket] {
        let active = subscriptions.filter { !$0.isArchived }
        let weekStart = startOfWeek(for: reference)

        return (0..<weeks).compactMap { offset -> WeekBucket? in
            guard let bucketStart = calendar.date(byAdding: .weekOfYear, value: offset, to: weekStart),
                  let bucketEnd = calendar.date(byAdding: .day, value: 7, to: bucketStart) else {
                return nil
            }
            let items = active.filter { sub in
                sub.nextRenewalDate >= bucketStart && sub.nextRenewalDate < bucketEnd
            }
            let total = items.reduce(Decimal(0)) { $0 + $1.amount }
            return WeekBucket(
                weekStart: bucketStart,
                weekEnd: calendar.date(byAdding: .day, value: -1, to: bucketEnd) ?? bucketEnd,
                total: total,
                count: items.count
            )
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}
