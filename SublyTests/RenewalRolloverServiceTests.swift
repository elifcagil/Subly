import XCTest
@testable import Subly

@MainActor
final class RenewalRolloverServiceTests: XCTestCase {

    // "Today" is fixed at 15 June 2026, 10:00 UTC.
    private var calendar: Calendar!
    private var now: Date!
    private var repository: InMemorySubscriptionRepository!
    private var scheduler: SpyNotificationScheduler!
    private var preferences: FakeSettingsPreferences!
    private var service: RenewalRolloverService!

    override func setUp() {
        super.setUp()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calendar = utc
        now = date(2026, 6, 15, hour: 10)
        repository = InMemorySubscriptionRepository()
        scheduler = SpyNotificationScheduler()
        preferences = FakeSettingsPreferences()
        service = RenewalRolloverService(
            repository: repository,
            notificationScheduler: scheduler,
            preferences: preferences,
            dateProvider: FixedDateProvider(now: now, calendar: calendar)
        )
    }

    // MARK: - Rolling

    func testExpiredMonthlyRollsToNextCycleAfterToday() async throws {
        // Renewed on the 10th; today is the 15th → next cycle is 10 July.
        let sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 6, 10))
        try await repository.save(sub)

        let rolled = await service.rollForwardExpired()

        XCTAssertEqual(rolled.map(\.id), [sub.id])
        let stored = try await repository.subscription(with: sub.id)
        XCTAssertEqual(stored.nextRenewalDate, date(2026, 7, 10))
    }

    func testLongDormantSubscriptionSkipsAllMissedCycles() async throws {
        // Last renewal recorded 3 Jan; app unopened for months → 3 July,
        // not 3 February.
        let sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 1, 3))
        try await repository.save(sub)

        _ = await service.rollForwardExpired()

        let stored = try await repository.subscription(with: sub.id)
        XCTAssertEqual(stored.nextRenewalDate, date(2026, 7, 3))
    }

    func testWeeklyQuarterlyYearlyCycles() async throws {
        let weekly = makeSubscription(cycle: .weekly, nextRenewal: date(2026, 6, 12))
        let quarterly = makeSubscription(cycle: .quarterly, nextRenewal: date(2026, 3, 1))
        let yearly = makeSubscription(cycle: .yearly, nextRenewal: date(2025, 8, 20))
        for sub in [weekly, quarterly, yearly] { try await repository.save(sub) }

        _ = await service.rollForwardExpired()

        let storedWeekly = try await repository.subscription(with: weekly.id)
        XCTAssertEqual(storedWeekly.nextRenewalDate, date(2026, 6, 19))
        let storedQuarterly = try await repository.subscription(with: quarterly.id)
        XCTAssertEqual(storedQuarterly.nextRenewalDate, date(2026, 9, 1))
        let storedYearly = try await repository.subscription(with: yearly.id)
        XCTAssertEqual(storedYearly.nextRenewalDate, date(2026, 8, 20))
    }

    func testMonthEndDatesFollowCalendarClamping() async throws {
        // 31 Jan → Calendar clamps: 28 Feb → 28 Mar … → first date ≥ today.
        let sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 1, 31))
        try await repository.save(sub)

        _ = await service.rollForwardExpired()

        let stored = try await repository.subscription(with: sub.id)
        XCTAssertEqual(stored.nextRenewalDate, date(2026, 6, 28))
    }

    // MARK: - Left untouched

    func testTodayRenewalIsNotAdvanced() async throws {
        let sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 6, 15))
        try await repository.save(sub)

        let rolled = await service.rollForwardExpired()

        XCTAssertTrue(rolled.isEmpty)
        let stored = try await repository.subscription(with: sub.id)
        XCTAssertEqual(stored.nextRenewalDate, date(2026, 6, 15))
    }

    func testArchivedSubscriptionIsNotAdvanced() async throws {
        var sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 6, 1))
        sub.isArchived = true
        try await repository.save(sub)

        let rolled = await service.rollForwardExpired()

        XCTAssertTrue(rolled.isEmpty)
        let stored = try await repository.subscription(with: sub.id)
        XCTAssertEqual(stored.nextRenewalDate, date(2026, 6, 1))
    }

    func testSecondPassIsIdempotent() async throws {
        let sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 6, 10))
        try await repository.save(sub)

        let first = await service.rollForwardExpired()
        let second = await service.rollForwardExpired()

        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(second.isEmpty)
    }

    // MARK: - Reminders

    func testRolledSubscriptionGetsRemindersRescheduled() async throws {
        var sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 6, 10))
        sub.reminderLeadDays = [1]
        try await repository.save(sub)

        _ = await service.rollForwardExpired()

        XCTAssertEqual(scheduler.scheduledCalls.count, 1)
        XCTAssertEqual(scheduler.scheduledCalls.first?.subscription.id, sub.id)
        XCTAssertEqual(scheduler.scheduledCalls.first?.leadDays, [1])
        XCTAssertEqual(
            scheduler.scheduledCalls.first?.subscription.nextRenewalDate,
            date(2026, 7, 10)
        )
    }

    func testNoRemindersRescheduledWhenGloballyDisabled() async throws {
        preferences.remindersEnabled = false
        var sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 6, 10))
        sub.reminderLeadDays = [1]
        try await repository.save(sub)

        _ = await service.rollForwardExpired()

        XCTAssertTrue(scheduler.scheduledCalls.isEmpty)
    }

    func testNoRemindersRescheduledWithoutLeadDays() async throws {
        let sub = makeSubscription(cycle: .monthly, nextRenewal: date(2026, 6, 10))
        try await repository.save(sub)

        _ = await service.rollForwardExpired()

        XCTAssertTrue(scheduler.scheduledCalls.isEmpty)
    }

    // MARK: - Helpers

    private func makeSubscription(cycle: BillingCycle, nextRenewal: Date) -> Subscription {
        Subscription(
            name: "Test",
            amount: 10,
            currencyCode: "USD",
            billingCycle: cycle,
            startDate: date(2025, 1, 1),
            nextRenewalDate: nextRenewal
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

// MARK: - Test doubles

private struct FixedDateProvider: DateProviding {
    let now: Date
    let calendar: Calendar
}

private final class SpyNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private(set) var scheduledCalls: [(subscription: Subscription, leadDays: [Int])] = []

    func requestAuthorization() async throws -> Bool { true }
    func schedule(for subscription: Subscription, leadDays: [Int]) async throws {
        scheduledCalls.append((subscription, leadDays))
    }
    func cancel(for subscriptionID: UUID) async {}
    func pendingIdentifiers(for subscriptionID: UUID) async -> [String] { [] }
    func registerActions() {}
    func snooze(identifier: String, by hours: Int) async throws {}
    func scheduleSmart(_ payloads: [SmartReminderPayload]) async {}
    func scheduleAwareness(_ payloads: [AwarenessPayload]) async {}
    func reconcileAll(smart: [SmartReminderPayload], awareness: [AwarenessPayload]) async {}
}

private final class FakeSettingsPreferences: SettingsPreferencesManaging, @unchecked Sendable {
    var remindersEnabled = true

    func current() -> SettingsPreferences {
        SettingsPreferences(
            defaultReminderLeadDays: [1],
            calendarExportEnabled: false,
            remindersEnabled: remindersEnabled
        )
    }
    func setDefaultReminderLeadDays(_ days: Set<Int>) {}
    func setCalendarExportEnabled(_ enabled: Bool) {}
    func setRemindersEnabled(_ enabled: Bool) {}
    func observe() -> AsyncStream<SettingsPreferences> {
        AsyncStream { $0.finish() }
    }
}
