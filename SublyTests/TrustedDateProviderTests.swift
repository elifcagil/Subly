import XCTest
@testable import Subly

final class TrustedDateProviderTests: XCTestCase {

    private final class FakeServer: ServerTimeFetching, @unchecked Sendable {
        var time: Date?
        func fetchServerTime() async -> Date? { time }
    }

    private final class FakeMonotonic: MonotonicClock, @unchecked Sendable {
        var uptime: TimeInterval = 1_000
        var bootID: TimeInterval = 42
    }

    private var server: FakeServer!
    private var monotonic: FakeMonotonic!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        server = FakeServer()
        monotonic = FakeMonotonic()
        let name = "TrustedDateProviderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
    }

    private func makeProvider() -> TrustedDateProvider {
        TrustedDateProvider(calendar: .current, fetcher: server, monotonic: monotonic, defaults: defaults)
    }

    func testFallsBackToTheDeviceClockBeforeTheFirstSync() {
        let provider = makeProvider()
        XCTAssertFalse(provider.hasSynced)
        XCTAssertEqual(provider.offset, 0)
        XCTAssertTrue(provider.isDeviceClockTrusted)
        XCTAssertEqual(provider.now.timeIntervalSinceNow, 0, accuracy: 1)
    }

    func testSyncAdoptsTheServerClock() async {
        // Device is one hour ahead of the server.
        server.time = Date().addingTimeInterval(-3600)
        let provider = makeProvider()
        let synced = await provider.sync()
        XCTAssertTrue(synced)
        XCTAssertEqual(provider.offset, -3600, accuracy: 2)
        XCTAssertFalse(provider.isDeviceClockTrusted)
        XCTAssertEqual(provider.now.timeIntervalSinceNow, -3600, accuracy: 2)
        // The trigger moment is expressed in device time.
        let trusted = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertEqual(provider.deviceDate(for: trusted).timeIntervalSince1970, 2_000_000_000 + 3600, accuracy: 2)
    }

    func testOfflineSyncKeepsThePreviousValue() async {
        server.time = Date().addingTimeInterval(-120)
        let provider = makeProvider()
        await provider.sync()
        server.time = nil
        let synced = await provider.sync()
        XCTAssertFalse(synced)
        XCTAssertEqual(provider.offset, -120, accuracy: 2)
    }

    func testSyncPersistsAcrossInstances() async {
        server.time = Date().addingTimeInterval(-300)
        await makeProvider().sync()
        let fresh = makeProvider()
        XCTAssertTrue(fresh.hasSynced)
        XCTAssertEqual(fresh.offset, -300, accuracy: 2)
    }

    func testMovingTheDeviceClockDoesNotMoveTrustedTime() async {
        server.time = Date()
        let provider = makeProvider()
        await provider.sync()
        let before = provider.now
        // The user jumps the wall clock a day ahead; the monotonic counter
        // only advanced 10s. `now` must follow the counter, not the clock.
        // (We cannot move Date() in a test, so assert via the offset model:
        // uptime +10s → trusted +10s, independent of Date().)
        monotonic.uptime += 10
        let after = provider.now
        XCTAssertEqual(after.timeIntervalSince(before), 10, accuracy: 2)
    }

    func testRFC1123DateHeaderParses() {
        let parsed = SupabaseServerTime.parse("Mon, 12 Oct 2026 20:31:07 GMT")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let expected = utc.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 20, minute: 31, second: 7))
        XCTAssertEqual(parsed, expected)
    }
}
