import Foundation
import Supabase

/// Switches flipped from the Supabase dashboard (`public.app_config`), so a
/// feature can be turned on or off without shipping a build. Values are
/// cached locally; offline, the last fetched value (or the default) applies.
protocol RemoteConfigProviding: AnyObject, Sendable {
    func bool(_ key: RemoteConfigKey, default fallback: Bool) -> Bool
    /// One fetch per call; returns once rows arrive, fail, or `maxWait` passes.
    func refresh(maxWait: TimeInterval) async
}

enum RemoteConfigKey: String {
    /// Show the What's New story for the running version.
    case whatsNewEnabled = "whats_new_enabled"
}

final class SupabaseRemoteConfigService: RemoteConfigProviding, @unchecked Sendable {

    private struct Row: Decodable {
        let key: String
        let value: AnyJSON
    }

    private static let cacheKey = "com.subly.app_config.v1"
    private let client: SupabaseClient
    private let defaults: UserDefaults
    private let logger: Logging
    private let lock = NSLock()
    private var values: [String: Bool]

    init(client: SupabaseClient, defaults: UserDefaults = .standard, logger: Logging) {
        self.client = client
        self.defaults = defaults
        self.logger = logger
        self.values = (defaults.dictionary(forKey: Self.cacheKey) as? [String: Bool]) ?? [:]
    }

    func bool(_ key: RemoteConfigKey, default fallback: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return values[key.rawValue] ?? fallback
    }

    func refresh(maxWait: TimeInterval = 3) async {
        let client = self.client
        let fetch = Task<[Row]?, Never> {
            try? await client.from("app_config").select("key,value").execute().value
        }
        let timeout = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: UInt64(maxWait * 1_000_000_000))
            fetch.cancel()
        }
        let rows = await fetch.value
        timeout.cancel()
        guard let rows, !rows.isEmpty else {
            logger.debug("Remote config: kept cached values.", category: "config")
            return
        }
        var parsed: [String: Bool] = [:]
        for row in rows {
            switch row.value {
            case .bool(let flag): parsed[row.key] = flag
            case .string(let text): parsed[row.key] = (text as NSString).boolValue
            case .integer(let number): parsed[row.key] = number != 0
            default: break
            }
        }
        lock.lock()
        values = parsed
        lock.unlock()
        defaults.set(parsed, forKey: Self.cacheKey)
        logger.info("Remote config refreshed (\(parsed.count) key(s)).", category: "config")
    }
}

/// Tests / previews: fixed values.
final class StaticRemoteConfigService: RemoteConfigProviding, @unchecked Sendable {
    var values: [RemoteConfigKey: Bool]
    init(_ values: [RemoteConfigKey: Bool] = [:]) { self.values = values }
    func bool(_ key: RemoteConfigKey, default fallback: Bool) -> Bool { values[key] ?? fallback }
    func refresh(maxWait: TimeInterval) async {}
}
