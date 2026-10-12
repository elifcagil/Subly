import XCTest
@testable import Subly

/// Ring math from the widget handoff: progress = (cycleDays − daysLeft) / cycleDays.
final class RenewalProgressCalculatorTests: XCTestCase {

    private var calendar: Calendar!
    private var calculator: RenewalProgressCalculator!

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
        calculator = RenewalProgressCalculator(calendar: calendar)
    }

    func testJustRenewedIsNearlyEmpty() {
        // Monthly, renews 15 Jul; today 15 Jun (30-day period) → 0 elapsed → floor 0.02.
        let p = calculator.progress(renewalDate: date(2026, 7, 15), cycle: .monthly, on: date(2026, 6, 15))
        XCTAssertEqual(p.daysLeft, 30)
        XCTAssertEqual(p.cycleDays, 30)
        XCTAssertEqual(p.fraction, 0.02, accuracy: 0.0001)
    }

    func testMidCycle() {
        let p = calculator.progress(renewalDate: date(2026, 7, 15), cycle: .monthly, on: date(2026, 6, 30))
        XCTAssertEqual(p.daysLeft, 15)
        XCTAssertEqual(p.fraction, 0.5, accuracy: 0.0001)
    }

    func testOneDayLeft() {
        let p = calculator.progress(renewalDate: date(2026, 7, 15), cycle: .monthly, on: date(2026, 7, 14))
        XCTAssertEqual(p.daysLeft, 1)
        XCTAssertEqual(p.fraction, 29.0 / 30.0, accuracy: 0.0001)
    }

    func testRenewalDayIsFull() {
        let p = calculator.progress(renewalDate: date(2026, 7, 15), cycle: .monthly, on: date(2026, 7, 15))
        XCTAssertEqual(p.daysLeft, 0)
        XCTAssertEqual(p.fraction, 1, accuracy: 0.0001)
    }

    func testYearlyCycleUsesActualYearLength() {
        // 2028 is a leap year: 1 Mar 2027 → 1 Mar 2028 = 366 days.
        let p = calculator.progress(renewalDate: date(2028, 3, 1), cycle: .yearly, on: date(2027, 9, 1))
        XCTAssertEqual(p.cycleDays, 366)
        XCTAssertEqual(p.daysLeft, 182)
        XCTAssertEqual(p.fraction, Double(366 - 182) / 366, accuracy: 0.0001)
    }

    func testWeeklyCycleIsSevenDays() {
        let p = calculator.progress(renewalDate: date(2026, 6, 22), cycle: .weekly, on: date(2026, 6, 18))
        XCTAssertEqual(p.cycleDays, 7)
        XCTAssertEqual(p.daysLeft, 4)
        XCTAssertEqual(p.fraction, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testCustomCycleFallsBackToMonthly() {
        // Custom has no explicit length in the model → treated as monthly
        // (same as the renewal calculator). Feb 2026 period = 28 days.
        let p = calculator.progress(renewalDate: date(2026, 3, 1), cycle: .custom, on: date(2026, 2, 15))
        XCTAssertEqual(p.cycleDays, 28)
        XCTAssertEqual(p.daysLeft, 14)
        XCTAssertEqual(p.fraction, 0.5, accuracy: 0.0001)
    }

    func testPastRenewalClampsToFull() {
        let p = calculator.progress(renewalDate: date(2026, 6, 10), cycle: .monthly, on: date(2026, 6, 15))
        XCTAssertEqual(p.daysLeft, 0)
        XCTAssertEqual(p.fraction, 1, accuracy: 0.0001)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
}
