import XCTest
@testable import Subly

final class RecapCadenceTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
    }

    func testRecapEveryThreeMonthsFromRegistration() {
        let cadence = RecapCadence(registeredAt: date(2026, 3, 14), calendar: calendar)
        XCTAssertEqual(cadence.recapDate(1), date(2026, 6, 14))
        XCTAssertEqual(cadence.recapDate(2), date(2026, 9, 14))
        XCTAssertEqual(cadence.recapDate(3), date(2026, 12, 14))
        XCTAssertEqual(cadence.recapDate(4), date(2027, 3, 14))
    }

    func testMonthEndRegistrationClampsToLastDay() {
        let cadence = RecapCadence(registeredAt: date(2026, 11, 30), calendar: calendar)
        // Nov 30 + 3 months → Feb 28 (2027 is not a leap year).
        XCTAssertEqual(cadence.recapDate(1), date(2027, 2, 28))
        // Nov 30 + 6 months → May 30.
        XCTAssertEqual(cadence.recapDate(2), date(2027, 5, 30))
    }

    func testPeriodsAreContiguousAndStartAtRegistration() {
        let cadence = RecapCadence(registeredAt: date(2026, 3, 14), calendar: calendar)
        XCTAssertEqual(cadence.period(1), DateInterval(start: date(2026, 3, 14), end: date(2026, 6, 14)))
        XCTAssertEqual(cadence.period(2).start, cadence.period(1).end)
    }

    func testLatestDueAndNextRecap() {
        let cadence = RecapCadence(registeredAt: date(2026, 3, 14), calendar: calendar)
        XCTAssertEqual(cadence.latestDueIndex(at: date(2026, 6, 13)), 0)
        XCTAssertEqual(cadence.latestDueIndex(at: date(2026, 6, 14)), 1)
        XCTAssertEqual(cadence.latestDueIndex(at: date(2026, 12, 20)), 3)
        XCTAssertEqual(cadence.nextRecapDate(after: date(2026, 6, 13)), date(2026, 6, 14))
        XCTAssertEqual(cadence.nextRecapDate(after: date(2026, 6, 14)), date(2026, 9, 14))
    }

    func testDueIndexCoveringADate() {
        let cadence = RecapCadence(registeredAt: date(2026, 3, 14), calendar: calendar)
        XCTAssertEqual(cadence.dueIndex(covering: date(2026, 4, 1), at: date(2026, 10, 1)), 1)
        XCTAssertEqual(cadence.dueIndex(covering: date(2026, 8, 1), at: date(2026, 10, 1)), 2)
        // Period 3 is not due yet on 1 Oct.
        XCTAssertNil(cadence.dueIndex(covering: date(2026, 9, 20), at: date(2026, 10, 1)))
    }

    func testPeriodLabelCrossingAYear() {
        let formatter = RecapPeriodFormatter(calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(formatter.label(for: DateInterval(start: date(2026, 4, 14), end: date(2026, 7, 14))), "April–June")
        XCTAssertEqual(formatter.label(for: DateInterval(start: date(2026, 11, 14), end: date(2027, 2, 14))), "November 2026–January 2027")
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
}
