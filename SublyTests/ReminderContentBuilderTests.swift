import XCTest
@testable import Subly

/// Pure-builder tests: fixed UTC calendar, "now" = 15 June 2026 10:00.
final class ReminderContentBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var now: Date!
    private var builder: ReminderContentBuilder!
    private let formatter = PlainCurrencyFormatter()

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
        now = date(2026, 6, 15, hour: 10)
        builder = ReminderContentBuilder(
            calendar: calendar,
            locale: Locale(identifier: "en_US"),
            currencyFormatter: formatter
        )
    }

    // MARK: - Lead + same-day

    func testLeadReminderFiresNDaysBeforeAtNine() {
        let sub = makeSubscription(name: "Netflix", nextRenewal: date(2026, 6, 20), leadDays: [3])

        let requests = builder.plan(subscriptions: [sub], now: now)

        let lead = requests.first { $0.kind == .lead(offsetDays: 3) }
        XCTAssertNotNil(lead)
        XCTAssertEqual(lead?.fireDate, date(2026, 6, 17, hour: 9))
        XCTAssertEqual(lead?.identifier, "reminder.\(sub.id.uuidString).2026-06-20")
        XCTAssertEqual(lead?.title, Strings.Reminders.titleInDays(name: "Netflix", days: 3))
        XCTAssertEqual(lead?.categoryIdentifier, ReminderCategory.standard)
        XCTAssertEqual(lead?.deliveryStyle, .normal)
        XCTAssertEqual(lead?.userInfo[ReminderUserInfoKey.offsetDays], "3")
        XCTAssertEqual(lead?.userInfo[ReminderUserInfoKey.subscriptionID], sub.id.uuidString)
        XCTAssertEqual(lead?.threadIdentifier, "renewals")
    }

    func testSameDayReminderIsAddedUnlessOffsetIsSameDay() {
        let withLead = makeSubscription(nextRenewal: date(2026, 6, 20), leadDays: [3])
        let sameDayOnly = makeSubscription(nextRenewal: date(2026, 6, 25), leadDays: [0])

        // 30-day horizon → one renewal each (the monthly follow-up is out).
        let forLead = builder.plan(subscriptions: [withLead], now: now, horizonDays: 30)
        let forSameDay = builder.plan(subscriptions: [sameDayOnly], now: now, horizonDays: 30)

        let sameDay = forLead.first { $0.kind == .sameDay }
        XCTAssertEqual(forLead.count, 2)
        XCTAssertEqual(sameDay?.identifier, "sameday.\(withLead.id.uuidString).2026-06-20")
        XCTAssertEqual(sameDay?.fireDate, date(2026, 6, 20, hour: 9))
        XCTAssertEqual(sameDay?.deliveryStyle, .timeSensitive)
        XCTAssertEqual(sameDay?.categoryIdentifier, ReminderCategory.imminent)

        // "Same day" offset → exactly one notification, no duplicate.
        XCTAssertEqual(forSameDay.count, 1)
        XCTAssertEqual(forSameDay.first?.title, Strings.Reminders.titleToday(name: "Test"))
    }

    func testAcknowledgedRenewalSkipsSameDay() {
        let sub = makeSubscription(nextRenewal: date(2026, 6, 20), leadDays: [3])

        let requests = builder.plan(
            subscriptions: [sub],
            acknowledged: [sub.id: "2026-06-20"],
            now: now,
            horizonDays: 30
        )

        XCTAssertEqual(requests.map(\.kind), [.lead(offsetDays: 3)])
    }

    // MARK: - Copy table

    func testCopyRowsPerOffset() {
        let week = makeSubscription(name: "Spotify", nextRenewal: date(2026, 6, 30), leadDays: [7])
        let tomorrow = makeSubscription(name: "iCloud+", nextRenewal: date(2026, 6, 30), leadDays: [1])
        let amount = formatter.string(from: 10, currencyCode: "USD")

        let weekRequest = builder.plan(subscriptions: [week], now: now).first { $0.kind == .lead(offsetDays: 7) }
        let tomorrowRequest = builder.plan(subscriptions: [tomorrow], now: now).first { $0.kind == .lead(offsetDays: 1) }
        let today = builder.plan(subscriptions: [week], now: now).first { $0.kind == .sameDay }

        XCTAssertEqual(weekRequest?.title, Strings.Reminders.titleWeek(name: "Spotify"))
        XCTAssertEqual(weekRequest?.body, Strings.Reminders.bodyWeek(amount: amount, date: "Tue, Jun 30"))
        XCTAssertEqual(tomorrowRequest?.title, Strings.Reminders.titleTomorrow(name: "iCloud+"))
        XCTAssertEqual(tomorrowRequest?.body, Strings.Reminders.bodyTomorrow(amount: amount))
        XCTAssertEqual(tomorrowRequest?.categoryIdentifier, ReminderCategory.imminent)
        XCTAssertEqual(today?.body, Strings.Reminders.bodyToday(amount: amount))
    }

    func testVerbAdaptsToCategory() {
        let streaming = makeSubscription(name: "Netflix", nextRenewal: date(2026, 6, 20), leadDays: [3], categoryID: Category.streamingID)
        let music = makeSubscription(name: "Spotify", nextRenewal: date(2026, 6, 22), leadDays: [3], categoryID: Category.musicID)
        let other = makeSubscription(name: "Notion", nextRenewal: date(2026, 6, 24), leadDays: [3])
        let amount = formatter.string(from: 10, currencyCode: "USD")

        func body(_ sub: Subscription) -> String? {
            builder.plan(subscriptions: [sub], now: now).first { $0.kind == .lead(offsetDays: 3) }?.body
        }

        XCTAssertEqual(body(streaming), Strings.Reminders.bodyInDays(amount: amount, date: "Sat, Jun 20", verb: Strings.Reminders.verbWatching))
        XCTAssertEqual(body(music), Strings.Reminders.bodyInDays(amount: amount, date: "Mon, Jun 22", verb: Strings.Reminders.verbListening))
        XCTAssertEqual(body(other), Strings.Reminders.bodyInDays(amount: amount, date: "Wed, Jun 24", verb: Strings.Reminders.verbUsing))
    }

    // MARK: - Quiet hours

    func testDeliveryInsideQuietHoursStaysOnTimeButSilent() {
        // Delivery at 23:00 is inside 22:00–08:00 → same time, silent.
        let late = ReminderContentBuilder(calendar: calendar, currencyFormatter: formatter, deliveryHour: 23)
        let sub = makeSubscription(nextRenewal: date(2026, 6, 20), leadDays: [3])

        let requests = late.plan(subscriptions: [sub], now: now, horizonDays: 30)
        let lead = requests.first { $0.kind == .lead(offsetDays: 3) }
        let sameDay = requests.first { $0.kind == .sameDay }

        XCTAssertEqual(lead?.fireDate, date(2026, 6, 17, hour: 23))
        XCTAssertEqual(lead?.deliveryStyle, .silent)
        XCTAssertEqual(sameDay?.deliveryStyle, .silent)
    }

    func testRenewalDayAlertsKeepSoundInsideQuietHours() {
        let late = ReminderContentBuilder(calendar: calendar, currencyFormatter: formatter, deliveryHour: 23)
        var quiet = QuietHours.default
        quiet.renewalDayAlertsWithSound = true
        let sub = makeSubscription(nextRenewal: date(2026, 6, 20), leadDays: [3])

        let requests = late.plan(subscriptions: [sub], quietHours: quiet, now: now, horizonDays: 30)

        XCTAssertEqual(requests.first { $0.kind == .sameDay }?.deliveryStyle, .timeSensitive)
        XCTAssertEqual(requests.first { $0.kind == .lead(offsetDays: 3) }?.deliveryStyle, .silent)
    }

    // MARK: - Grouping

    func testTwoRenewalsOnTheSameDeliveryDayBecomeOneNotification() {
        let netflix = makeSubscription(name: "Netflix", amount: 15, nextRenewal: date(2026, 6, 20), leadDays: [1])
        let spotify = makeSubscription(name: "Spotify", amount: 10, nextRenewal: date(2026, 6, 20), leadDays: [1])

        let requests = builder.plan(subscriptions: [netflix, spotify], now: now, horizonDays: 30)

        // Jun 19 (both "tomorrow" reminders) and Jun 20 (both same-day) → 2.
        XCTAssertEqual(requests.count, 2)
        let grouped = requests.first { $0.identifier == "grouped.2026-06-19" }
        XCTAssertEqual(grouped?.kind, .grouped)
        XCTAssertEqual(grouped?.title, Strings.Reminders.groupedTitleTomorrow(count: 2))
        XCTAssertEqual(
            grouped?.body,
            Strings.Reminders.groupedBodyTwo("Netflix", "Spotify", total: formatter.string(from: 25, currencyCode: "USD"))
        )
        XCTAssertEqual(grouped?.categoryIdentifier, ReminderCategory.grouped)
        XCTAssertEqual(grouped?.userInfo[ReminderUserInfoKey.subscriptionIDs]?.split(separator: ",").count, 2)

        let sameDay = requests.first { $0.identifier == "grouped.2026-06-20" }
        XCTAssertEqual(sameDay?.title, Strings.Reminders.groupedTitleToday(count: 2))
        XCTAssertEqual(sameDay?.deliveryStyle, .timeSensitive)
    }

    func testGroupedTotalsNeverMixCurrencies() {
        let usd = makeSubscription(name: "A", amount: 15, currency: "USD", nextRenewal: date(2026, 6, 20), leadDays: [0])
        let eur = makeSubscription(name: "B", amount: 10, currency: "EUR", nextRenewal: date(2026, 6, 20), leadDays: [0])

        let grouped = builder.plan(subscriptions: [usd, eur], now: now).first

        let total = "\(formatter.string(from: 10, currencyCode: "EUR")) + \(formatter.string(from: 15, currencyCode: "USD"))"
        XCTAssertEqual(grouped?.body, Strings.Reminders.groupedBodyTwo("A", "B", total: total))
    }

    func testGroupedBodyCollapsesBeyondThreeNames() {
        let subs = ["A", "B", "C", "D"].map {
            makeSubscription(name: $0, amount: 1, nextRenewal: date(2026, 6, 20), leadDays: [0])
        }

        let grouped = builder.plan(subscriptions: subs, now: now).first

        XCTAssertEqual(
            grouped?.body,
            Strings.Reminders.groupedBodyMore("A", "B", more: 2, total: formatter.string(from: 4, currencyCode: "USD"))
        )
    }

    // MARK: - Horizon, past, cap

    func testHorizonCoversSixtyDaysOfRenewals() {
        // Monthly from Jun 20: Jun 20, Jul 20 inside; Aug 20 (day 66) outside.
        let sub = makeSubscription(nextRenewal: date(2026, 6, 20), leadDays: [0])

        let requests = builder.plan(subscriptions: [sub], now: now)

        XCTAssertEqual(requests.map(\.fireDate), [date(2026, 6, 20, hour: 9), date(2026, 7, 20, hour: 9)])
    }

    func testDeliveryTimeAlreadyPassedTodayIsSkipped() {
        // Renews today; 09:00 is behind "now" (10:00) → only next month's.
        let sub = makeSubscription(nextRenewal: date(2026, 6, 15), leadDays: [0])

        let requests = builder.plan(subscriptions: [sub], now: now)

        XCTAssertEqual(requests.map(\.fireDate), [date(2026, 7, 15, hour: 9)])
    }

    func testStaleRenewalDateIsProjectedForward() {
        // Store still says 10 May (app unopened) → next cycle after today is 10 Jul.
        let sub = makeSubscription(nextRenewal: date(2026, 5, 10), leadDays: [0])

        let requests = builder.plan(subscriptions: [sub], now: now)

        XCTAssertEqual(requests.first?.fireDate, date(2026, 7, 10, hour: 9))
    }

    func testCapKeepsTheSoonestRequests() {
        let subs = (1...10).map { day in
            makeSubscription(name: "S\(day)", nextRenewal: date(2026, 6, 15 + day), leadDays: [0])
        }

        let requests = builder.plan(subscriptions: subs, now: now, limit: 3)

        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests.map(\.fireDate), [
            date(2026, 6, 16, hour: 9), date(2026, 6, 17, hour: 9), date(2026, 6, 18, hour: 9)
        ])
    }

    func testArchivedAndUnsetSubscriptionsAreIgnored() {
        var archived = makeSubscription(nextRenewal: date(2026, 6, 20), leadDays: [1])
        archived.isArchived = true
        let noReminder = makeSubscription(nextRenewal: date(2026, 6, 20), leadDays: [])

        XCTAssertTrue(builder.plan(subscriptions: [archived, noReminder], now: now).isEmpty)
    }

    // MARK: - Snooze

    func testSnoozedRequestFiresTomorrowWithRecomputedDays() {
        let sub = makeSubscription(name: "Netflix", nextRenewal: date(2026, 6, 20), leadDays: [3])
        let original = builder.plan(subscriptions: [sub], now: now).first { $0.kind == .lead(offsetDays: 3) }!
        let deliveredAt = date(2026, 6, 17, hour: 9, minute: 5)

        let snoozed = builder.snoozedRequest(from: original.userInfo, now: deliveredAt)

        XCTAssertEqual(snoozed?.kind, .snoozed)
        XCTAssertEqual(snoozed?.fireDate, date(2026, 6, 18, hour: 9))
        XCTAssertEqual(snoozed?.title, Strings.Reminders.titleInDays(name: "Netflix", days: 2))
        XCTAssertEqual(snoozed?.identifier, "snoozed.\(sub.id.uuidString).2026-06-20")
    }

    func testSnoozeAfterRenewalReturnsNil() {
        let sub = makeSubscription(nextRenewal: date(2026, 6, 20), leadDays: [0])
        let original = builder.plan(subscriptions: [sub], now: now).first!

        XCTAssertNil(builder.snoozedRequest(from: original.userInfo, now: date(2026, 6, 20, hour: 9)))
    }

    // MARK: - Helpers

    private func makeSubscription(
        name: String = "Test",
        amount: Decimal = 10,
        currency: String = "USD",
        nextRenewal: Date,
        leadDays: [Int],
        categoryID: UUID? = nil
    ) -> Subscription {
        Subscription(
            name: name,
            amount: amount,
            currencyCode: currency,
            billingCycle: .monthly,
            startDate: date(2025, 1, 1),
            nextRenewalDate: nextRenewal,
            categoryIDs: categoryID.map { [$0] } ?? [],
            reminderLeadDays: leadDays
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

/// "10 USD" — deterministic regardless of locale.
private struct PlainCurrencyFormatter: CurrencyFormatting {
    func string(from amount: Decimal, currencyCode: String) -> String { "\(amount) \(currencyCode)" }
    func string(from amount: Decimal, currency: Currency) -> String { string(from: amount, currencyCode: currency.code) }
    func string(from amount: Decimal, currencyCode: String, locale: Locale) -> String { string(from: amount, currencyCode: currencyCode) }
}
