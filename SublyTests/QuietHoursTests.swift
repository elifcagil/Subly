import XCTest
@testable import Subly

final class QuietHoursTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
    }

    func testWindowAcrossMidnightWithInclusiveStartExclusiveEnd() {
        let quiet = QuietHours.default  // 22:00–08:00, every day
        XCTAssertTrue(quiet.isQuiet(at: date(2026, 6, 15, 22, 0), calendar: calendar))
        XCTAssertTrue(quiet.isQuiet(at: date(2026, 6, 16, 3, 30), calendar: calendar))
        XCTAssertTrue(quiet.isQuiet(at: date(2026, 6, 16, 7, 59), calendar: calendar))
        XCTAssertFalse(quiet.isQuiet(at: date(2026, 6, 16, 8, 0), calendar: calendar))
        XCTAssertFalse(quiet.isQuiet(at: date(2026, 6, 15, 21, 59), calendar: calendar))
        XCTAssertEqual(quiet.durationMinutes, 600)
    }

    func testSameStartAndEndMeansNoWindow() {
        var quiet = QuietHours.default
        quiet.start = DateComponents(hour: 9, minute: 0)
        quiet.end = DateComponents(hour: 9, minute: 0)
        XCTAssertFalse(quiet.hasWindow)
        XCTAssertFalse(quiet.isQuiet(at: date(2026, 6, 15, 9, 0), calendar: calendar))
    }

    func testDisabledIsNeverQuiet() {
        var quiet = QuietHours.default
        quiet.isEnabled = false
        XCTAssertFalse(quiet.isQuiet(at: date(2026, 6, 15, 23, 0), calendar: calendar))
    }

    func testWeekdaysAreKeyedByTheWindowStartDay() {
        var quiet = QuietHours.default
        // Friday only (weekday 6). 19 Jun 2026 is a Friday.
        quiet.weekdays = [6]
        XCTAssertTrue(quiet.isQuiet(at: date(2026, 6, 19, 23, 0), calendar: calendar))
        // Saturday 03:00 belongs to Friday's window.
        XCTAssertTrue(quiet.isQuiet(at: date(2026, 6, 20, 3, 0), calendar: calendar))
        // Saturday 23:00 starts Saturday's window → not selected.
        XCTAssertFalse(quiet.isQuiet(at: date(2026, 6, 20, 23, 0), calendar: calendar))
    }

    func testDaytimeWindowDoesNotCrossMidnight() {
        var quiet = QuietHours.default
        quiet.start = DateComponents(hour: 13, minute: 0)
        quiet.end = DateComponents(hour: 14, minute: 30)
        XCTAssertTrue(quiet.isQuiet(at: date(2026, 6, 15, 13, 45), calendar: calendar))
        XCTAssertFalse(quiet.isQuiet(at: date(2026, 6, 15, 14, 30), calendar: calendar))
        XCTAssertEqual(quiet.durationMinutes, 90)
    }

    func testAcrossDaylightSavingTransition() {
        // Europe/Istanbul had DST until 2016; use Europe/Berlin: 29 Mar 2026 02:00 → 03:00.
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let quiet = QuietHours.default
        let components = DateComponents(year: 2026, month: 3, day: 29, hour: 3, minute: 30)
        let after = berlin.date(from: components)!
        XCTAssertTrue(quiet.isQuiet(at: after, calendar: berlin))
        let morning = berlin.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 8, minute: 0))!
        XCTAssertFalse(quiet.isQuiet(at: morning, calendar: berlin))
    }

    func testDeliveryStyles() {
        var quiet = QuietHours.default
        let inside = date(2026, 6, 15, 23, 0)
        let outside = date(2026, 6, 15, 9, 0)
        XCTAssertEqual(quiet.deliveryStyle(for: inside, isSameDay: false, calendar: calendar), .silent)
        XCTAssertEqual(quiet.deliveryStyle(for: inside, isSameDay: true, calendar: calendar), .silent)
        XCTAssertEqual(quiet.deliveryStyle(for: outside, isSameDay: false, calendar: calendar), .normal)
        XCTAssertEqual(quiet.deliveryStyle(for: outside, isSameDay: true, calendar: calendar), .timeSensitive)
        quiet.renewalDayAlertsWithSound = true
        XCTAssertEqual(quiet.deliveryStyle(for: inside, isSameDay: true, calendar: calendar), .timeSensitive)
        XCTAssertEqual(quiet.deliveryStyle(for: inside, isSameDay: false, calendar: calendar), .silent)
    }

    func testPresetMatching() {
        XCTAssertTrue(QuietHours.default.matchesPreset(QuietHours.presets[0]))
        var custom = QuietHours.default
        custom.start = DateComponents(hour: 22, minute: 15)
        XCTAssertFalse(custom.matchesPreset(QuietHours.presets[0]))
    }

    func testRoundTripsThroughTheStore() {
        let defaults = UserDefaults(suiteName: "QuietHoursTests")!
        defaults.removePersistentDomain(forName: "QuietHoursTests")
        let store = QuietHoursStore(defaults: defaults, calendar: calendar)
        var value = QuietHours.default
        value.weekdays = [2, 3, 4, 5, 6]
        value.renewalDayAlertsWithSound = true
        MainActor.assumeIsolated {
            store.set(value)
            XCTAssertEqual(store.current(), value)
        }
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}
