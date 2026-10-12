import XCTest
@testable import Subly

final class RecapStoryStateTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
    }

    func testHiddenBeforeTheFirstRecap() {
        XCTAssertNil(RecapStoryState.resolve(latestDueIndex: 0, recapDate: date(2026, 6, 14), lastSeenIndex: 0, now: date(2026, 6, 13), calendar: calendar))
    }

    func testReadyOnRecapDate() {
        XCTAssertEqual(RecapStoryState.resolve(latestDueIndex: 1, recapDate: date(2026, 6, 14), lastSeenIndex: 0, now: date(2026, 6, 14), calendar: calendar), .ready)
    }

    func testSeenAfterOpening() {
        XCTAssertEqual(RecapStoryState.resolve(latestDueIndex: 1, recapDate: date(2026, 6, 14), lastSeenIndex: 1, now: date(2026, 6, 16), calendar: calendar), .seen)
    }

    func testHiddenAfterSevenDays() {
        XCTAssertEqual(RecapStoryState.resolve(latestDueIndex: 1, recapDate: date(2026, 6, 14), lastSeenIndex: 1, now: date(2026, 6, 20), calendar: calendar), .seen)
        XCTAssertNil(RecapStoryState.resolve(latestDueIndex: 1, recapDate: date(2026, 6, 14), lastSeenIndex: 1, now: date(2026, 6, 21), calendar: calendar))
        XCTAssertNil(RecapStoryState.resolve(latestDueIndex: 1, recapDate: date(2026, 6, 14), lastSeenIndex: 0, now: date(2026, 6, 21), calendar: calendar))
    }

    func testNextRecapResetsToReady() {
        XCTAssertEqual(RecapStoryState.resolve(latestDueIndex: 2, recapDate: date(2026, 9, 14), lastSeenIndex: 1, now: date(2026, 9, 14), calendar: calendar), .ready)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
}
