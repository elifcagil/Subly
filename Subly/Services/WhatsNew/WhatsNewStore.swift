import Foundation

/// Remembers which app version's What's New story the user has seen.
protocol WhatsNewStoring: AnyObject {
    var lastSeenVersion: String? { get }
    func markSeen(version: String)
}

final class WhatsNewStore: WhatsNewStoring {
    private let key = "com.subly.whats_new.last_seen_version"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastSeenVersion: String? {
        defaults.string(forKey: key)
    }

    func markSeen(version: String) {
        defaults.set(version, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}

/// The running app's marketing version.
enum AppVersion {
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
