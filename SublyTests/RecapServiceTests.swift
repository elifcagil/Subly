import XCTest
@testable import Subly

final class RecapServiceTests: XCTestCase {

    private var calendar: Calendar!
    private var service: RecapService!
    // Registered 14 Mar 2026 → period 1 = 14 Mar – 14 Jun, period 2 = 14 Jun – 14 Sep.
    private var period1: DateInterval!
    private var period2: DateInterval!

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
        service = RecapService(calendar: calendar)
        period1 = DateInterval(start: date(2026, 3, 14), end: date(2026, 6, 14))
        period2 = DateInterval(start: date(2026, 6, 14), end: date(2026, 9, 14))
    }

    func testFirstRecapNeedsASubscriptionForTheWholePeriod() {
        let young = make("Netflix", amount: 15, start: date(2026, 4, 1))
        XCTAssertNil(service.recap(index: 1, period: period1, previousPeriod: nil, subscriptions: [young], preferredCurrencyCode: "USD", now: date(2026, 6, 14)))

        let old = make("Netflix", amount: 15, start: date(2026, 1, 1))
        XCTAssertNotNil(service.recap(index: 1, period: period1, previousPeriod: nil, subscriptions: [old], preferredCurrencyCode: "USD", now: date(2026, 6, 14)))
    }

    func testTotalsBarsAndNoComparisonOnFirstRecap() throws {
        // Monthly from 1 Jan: charges on 1 Apr, 1 May, 1 Jun inside period 1 → 3 × 15.
        let netflix = make("Netflix", amount: 15, start: date(2026, 1, 1))
        // Monthly from 20 Mar: 20 Mar, 20 Apr, 20 May → 3 × 10.
        let spotify = make("Spotify", amount: 10, start: date(2026, 3, 20))

        let recap = try XCTUnwrap(service.recap(index: 1, period: period1, previousPeriod: nil, subscriptions: [netflix, spotify], preferredCurrencyCode: "USD", now: date(2026, 6, 14)))

        XCTAssertEqual(recap.total, 75)
        XCTAssertEqual(recap.subscriptionCount, 2)
        XCTAssertEqual(recap.monthBars.count, 3)
        XCTAssertEqual(recap.monthBars.map(\.total), [25, 25, 25])
        XCTAssertNil(recap.comparison)
        XCTAssertEqual(recap.topItem?.subscription.id, netflix.id)
        XCTAssertEqual(recap.topItem?.paid, 45)
        XCTAssertEqual(recap.topItem.map { Int(($0.share * 100).rounded()) }, 60)
        XCTAssertEqual(recap.cards, [.total, .mostExpensive, .longestRunning, .summary])
    }

    func testSecondRecapComparesWithPreviousPeriod() throws {
        let netflix = make("Netflix", amount: 15, start: date(2026, 1, 1))
        let added = make("Claude", amount: 20, start: date(2026, 7, 1))

        let recap = try XCTUnwrap(service.recap(index: 2, period: period2, previousPeriod: period1, subscriptions: [netflix, added], preferredCurrencyCode: "USD", now: date(2026, 9, 14)))

        // Period 2: Netflix 1 Jul, 1 Aug, 1 Sep = 45; Claude 1 Jul, 1 Aug, 1 Sep = 60 → 105.
        // Period 1: Netflix 45 → delta +60.
        XCTAssertEqual(recap.total, 105)
        XCTAssertEqual(recap.comparison?.delta, 60)
        XCTAssertEqual(recap.topItem?.subscription.id, added.id)
    }

    func testLongestRunningAndArchivedExcluded() throws {
        var archived = make("Old", amount: 5, start: date(2020, 1, 1))
        archived.isArchived = true
        let spotify = make("Spotify", amount: 10, start: date(2024, 6, 1))
        let netflix = make("Netflix", amount: 15, start: date(2026, 1, 1))

        let recap = try XCTUnwrap(service.recap(index: 1, period: period1, previousPeriod: nil, subscriptions: [archived, spotify, netflix], preferredCurrencyCode: "USD", now: date(2026, 6, 14)))

        XCTAssertEqual(recap.longestRunning?.subscription.id, spotify.id)
        XCTAssertEqual(recap.longestRunning?.months, 24)
        // 1 Jun 2024 … 1 Jun 2026 inclusive = 25 charges × 10.
        XCTAssertEqual(recap.longestRunning?.totalPaid, 250)
    }

    func testUsesTheDominantCurrencyWithoutConverting() throws {
        let usd1 = make("A", amount: 10, currency: "USD", start: date(2026, 1, 1))
        let usd2 = make("B", amount: 10, currency: "USD", start: date(2026, 1, 1))
        let eur = make("C", amount: 100, currency: "EUR", start: date(2026, 1, 1))

        let recap = try XCTUnwrap(service.recap(index: 1, period: period1, previousPeriod: nil, subscriptions: [usd1, usd2, eur], preferredCurrencyCode: "EUR", now: date(2026, 6, 14)))

        XCTAssertEqual(recap.currencyCode, "USD")
        XCTAssertEqual(recap.total, 60)
    }

    func testPaymentProjectorCountsChargesInsideInterval() {
        let projector = PaymentProjector(calendar: calendar)
        let yearly = Subscription(name: "Y", amount: 120, currencyCode: "USD", billingCycle: .yearly, startDate: date(2025, 5, 1), nextRenewalDate: date(2026, 5, 1))
        XCTAssertEqual(projector.paymentDates(for: yearly, in: period1), [date(2026, 5, 1)])
        XCTAssertEqual(projector.amountPaid(by: yearly, in: period2), 0)
    }

    private func make(_ name: String, amount: Decimal, currency: String = "USD", start: Date) -> Subscription {
        Subscription(name: name, amount: amount, currencyCode: currency, billingCycle: .monthly,
                     startDate: start, nextRenewalDate: calendar.date(byAdding: .month, value: 1, to: start)!)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
}
