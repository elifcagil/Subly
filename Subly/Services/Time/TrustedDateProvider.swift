import Foundation

/// Where the trusted "now" comes from: the backend's clock.
protocol ServerTimeFetching: Sendable {
    /// The server's current time, or nil when unreachable.
    func fetchServerTime() async -> Date?
}

/// Reads the `Date` header of a HEAD request to the Supabase host — no auth,
/// no body, one round trip. Supabase answers from the same clock that stamps
/// every row, so this is "official" time for the app.
struct SupabaseServerTime: ServerTimeFetching {
    var url: URL = SupabaseConfig.url
    var timeout: TimeInterval = 6

    func fetchServerTime() async -> Date? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              let header = http.value(forHTTPHeaderField: "Date") else { return nil }
        return Self.parse(header)
    }

    /// RFC 1123 ("Mon, 12 Oct 2026 20:31:07 GMT").
    static func parse(_ header: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: header)
    }
}

/// Monotonic seconds since boot that keep counting through sleep and are
/// immune to the user changing the wall clock. On Darwin `kern.boottime` is
/// moved whenever the clock is set, so `wall − boottime` stays monotonic.
protocol MonotonicClock: Sendable {
    /// Seconds since boot.
    var uptime: TimeInterval { get }
    /// Identifies this boot; changes after a restart.
    var bootID: TimeInterval { get }
}

struct SystemMonotonicClock: MonotonicClock {
    var bootTime: TimeInterval {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &tv, &size, nil, 0) == 0 else { return 0 }
        return TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000
    }

    var uptime: TimeInterval { Date().timeIntervalSince1970 - bootTime }
    var bootID: TimeInterval { bootTime.rounded() }
}

/// "Official" time for scheduling: the server's clock, carried forward by a
/// monotonic counter so the user cannot move it by changing the device
/// clock. Falls back to the device clock until the first successful sync.
///
/// What it protects: which reminders are due, roll-forward of renewal dates
/// and the recap cadence are all computed from `now`. What it cannot
/// protect: iOS fires a local notification by the device clock. To keep the
/// *moment* right, `deviceDate(for:)` converts a trusted fire date into the
/// device's time before scheduling, and a clock change re-plans everything.
final class TrustedDateProvider: DateProviding, @unchecked Sendable {

    /// Device clock drift above this is reported as untrusted.
    static let skewTolerance: TimeInterval = 5 * 60

    private struct Sync: Codable {
        let serverTime: TimeInterval
        let deviceTime: TimeInterval
        let uptime: TimeInterval
        let bootID: TimeInterval
    }

    let calendar: Calendar
    private let fetcher: ServerTimeFetching
    private let monotonic: MonotonicClock
    private let defaults: UserDefaults
    private let key = "com.subly.time.last_sync"
    private let lock = NSLock()
    private var sync: Sync?

    init(
        calendar: Calendar = .current,
        fetcher: ServerTimeFetching = SupabaseServerTime(),
        monotonic: MonotonicClock = SystemMonotonicClock(),
        defaults: UserDefaults = .standard
    ) {
        self.calendar = calendar
        self.fetcher = fetcher
        self.monotonic = monotonic
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            sync = try? JSONDecoder().decode(Sync.self, from: data)
        }
    }

    // MARK: - DateProviding

    var now: Date {
        Date(timeIntervalSince1970: Date().timeIntervalSince1970 + offset)
    }

    /// Trusted minus device clock. 0 before the first sync.
    var offset: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let sync else { return 0 }
        let device = Date().timeIntervalSince1970
        if sync.bootID == monotonic.bootID {
            // Same boot: carry the server time forward on the monotonic
            // counter, so a changed wall clock does not move "now".
            let trusted = sync.serverTime + (monotonic.uptime - sync.uptime)
            return trusted - device
        }
        // Rebooted since: the counter restarted; keep the last known skew.
        return sync.serverTime - sync.deviceTime
    }

    var hasSynced: Bool {
        lock.lock(); defer { lock.unlock() }
        return sync != nil
    }

    /// `true` when the device clock is within tolerance of trusted time.
    var isDeviceClockTrusted: Bool { abs(offset) <= Self.skewTolerance }

    /// A trusted moment expressed in the device's clock, for
    /// `UNCalendarNotificationTrigger`.
    func deviceDate(for trusted: Date) -> Date {
        trusted.addingTimeInterval(-offset)
    }

    // MARK: - Sync

    /// One round trip to the server; keeps the previous sync when offline.
    /// Returns `true` when the clock was refreshed.
    @discardableResult
    func sync() async -> Bool {
        let sentAt = Date()
        let uptimeBefore = monotonic.uptime
        guard let server = await fetcher.fetchServerTime() else { return false }
        let roundTrip = Date().timeIntervalSince(sentAt)
        // The header is stamped mid-flight; split the round trip.
        let serverNow = server.timeIntervalSince1970 + roundTrip / 2
        let value = Sync(
            serverTime: serverNow,
            deviceTime: sentAt.timeIntervalSince1970 + roundTrip / 2,
            uptime: uptimeBefore + roundTrip / 2,
            bootID: monotonic.bootID
        )
        lock.lock()
        sync = value
        lock.unlock()
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
        return true
    }
}
