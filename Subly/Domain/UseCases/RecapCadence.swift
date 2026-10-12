import Foundation

/// When recaps happen: every 3 calendar months after the device registered.
///
/// `recapDate(n) = registeredAt + 3n months` (n ≥ 1). Registrations on the
/// 29th–31st clamp to the last day of the target month (Calendar behaviour).
/// Period n covers `[recapDate(n−1), recapDate(n))`; the first period starts
/// at `registeredAt`.
struct RecapCadence: Sendable {

    static let monthsPerPeriod = 3

    let registeredAt: Date
    private let calendar: Calendar

    init(registeredAt: Date, calendar: Calendar = .current) {
        self.registeredAt = calendar.startOfDay(for: registeredAt)
        self.calendar = calendar
    }

    func recapDate(_ index: Int) -> Date {
        calendar.date(byAdding: .month, value: Self.monthsPerPeriod * index, to: registeredAt) ?? registeredAt
    }

    func period(_ index: Int) -> DateInterval {
        DateInterval(start: recapDate(index - 1), end: recapDate(index))
    }

    /// Highest index whose recap date is on or before `date` (0 = none yet).
    func latestDueIndex(at date: Date) -> Int {
        var index = 0
        while recapDate(index + 1) <= date && index < 400 { index += 1 }
        return index
    }

    /// The next recap date strictly after `date`.
    func nextRecapDate(after date: Date) -> Date {
        recapDate(latestDueIndex(at: date) + 1)
    }

    /// Recap index whose period contains `date`, if that recap is already due.
    func dueIndex(covering date: Date, at now: Date) -> Int? {
        let latest = latestDueIndex(at: now)
        guard latest >= 1 else { return nil }
        for index in 1...latest where period(index).contains(date) {
            return index
        }
        return nil
    }
}
