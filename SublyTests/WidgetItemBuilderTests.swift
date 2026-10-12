import XCTest
@testable import Subly

final class WidgetItemBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var builder: WidgetItemBuilder!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
        builder = WidgetItemBuilder(calendar: calendar)
        now = date(2026, 6, 15, hour: 10)
    }

    func testSoonestFirstAndLimited() {
        let subs = [
            make("Later", renewal: date(2026, 7, 1)),
            make("Soon", renewal: date(2026, 6, 16)),
            make("Mid", renewal: date(2026, 6, 20))
        ]

        let items = builder.items(from: subs, limit: 2, on: now)

        XCTAssertEqual(items.map(\.name), ["Soon", "Mid"])
        XCTAssertEqual(items.first?.daysLeft, 1)
    }

    func testPinnedKeepsUserOrderAndSkipsArchived() {
        var archived = make("Archived", renewal: date(2026, 6, 16))
        archived.isArchived = true
        let a = make("A", renewal: date(2026, 7, 1))
        let b = make("B", renewal: date(2026, 6, 20))

        let items = builder.items(from: [archived, a, b], pinned: [b.id, archived.id, a.id], limit: 3, on: now)

        XCTAssertEqual(items.map(\.name), ["B", "A"])
    }

    func testStaleRenewalIsProjectedForward() {
        let stale = make("Stale", renewal: date(2026, 5, 10))

        let item = builder.items(from: [stale], limit: 1, on: now).first

        XCTAssertEqual(item?.renewalDate, date(2026, 7, 10))
        XCTAssertEqual(item?.daysLeft, 25)
    }

    func testBrandTileAndNeutralTile() {
        let items = builder.items(from: [make("Netflix", renewal: date(2026, 6, 20)), make("Gym", renewal: date(2026, 6, 21))], limit: 2, on: now)

        XCTAssertEqual(items[0].tile.initial, "N")
        XCTAssertTrue(items[0].tile.isBrand)
        XCTAssertEqual(items[1].tile.initial, "G")
        XCTAssertFalse(items[1].tile.isBrand)
    }

    func testWeeklyTotalsPerCurrency() {
        let subs = [
            make("A", amount: 10, currency: "USD", renewal: date(2026, 6, 16)),
            make("B", amount: 5, currency: "USD", renewal: date(2026, 6, 21)),
            make("C", amount: 7, currency: "EUR", renewal: date(2026, 6, 18)),
            make("Out", amount: 99, currency: "USD", renewal: date(2026, 6, 30))
        ]
        let items = builder.items(from: subs, limit: 10, on: now)

        let totals = builder.weeklyTotals(of: items, on: now)

        XCTAssertEqual(totals.map(\.currencyCode), ["EUR", "USD"])
        XCTAssertEqual(totals.map(\.total), [7, 15])
    }

    private func make(_ name: String, amount: Decimal = 10, currency: String = "USD", renewal: Date) -> Subscription {
        Subscription(name: name, amount: amount, currencyCode: currency, billingCycle: .monthly,
                     startDate: date(2025, 1, 1), nextRenewalDate: renewal)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }
}
