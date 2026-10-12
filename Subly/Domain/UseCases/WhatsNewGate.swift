import Foundation

/// Decides whether the What's New story opens on launch: once per app
/// version, only after an update (never on a fresh install, whose seen
/// version is stamped at registration), and only when this build ships a
/// payload for the running version.
enum WhatsNewGate {

    static func shouldShow(currentVersion: String, lastSeenVersion: String?, hasPayload: Bool) -> Bool {
        guard hasPayload else { return false }
        guard let lastSeenVersion else { return true }
        return compare(currentVersion, lastSeenVersion) == .orderedDescending
    }

    /// Numeric, component-wise ("1.10.0" > "1.9.2"; "1.0" == "1.0.0").
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        let width = max(left.count, right.count)
        for index in 0..<width {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a < b ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
    }
}
