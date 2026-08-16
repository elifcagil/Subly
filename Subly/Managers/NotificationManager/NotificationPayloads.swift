import Foundation

// MARK: - Smart reminder

/// A notification *about a group of subscriptions* — never a single one.
///
/// Roadmap §9.5 Tier 2. Identifier shape: `smart.{kind}.{anchorISO}`.
struct SmartReminderPayload: Hashable, Sendable {

    enum Kind: String, Hashable, Sendable {
        /// "5 subscriptions renewing this week"
        case weekly
        /// "Tomorrow is a heavy day"
        case dailyHeavy
        /// "Two new charges starting on Monday"
        case newStarts
    }

    let kind: Kind
    let anchorDate: Date
    let fireDate: Date
    let title: String
    let body: String

    /// `smart.{kind}.{anchorYYYY-MM-dd}`
    var identifier: String {
        let key = NotificationIdentifierFormatter.dayKey(for: anchorDate)
        return "\(NotificationIdentifierPrefix.smart)\(kind.rawValue).\(key)"
    }

    /// Throttle priority — `Renewal > Smart > Awareness`.
    var priority: NotificationPriority { .medium }
}

// MARK: - Awareness

/// A notification *about spending pressure over time* — not about individual
/// events. Roadmap §9.5 Tier 3. Identifier shape: `awareness.{kind}.{anchorISO}`.
struct AwarenessPayload: Hashable, Sendable {

    enum Kind: String, Hashable, Sendable {
        /// "Heads up — ₺780 in the next 3 days"
        case horizonPressure
        /// "Entertainment is heavy this week"
        case categoryPressure
        /// "Monthly subscription spend is trending up"
        case trendUp
    }

    let kind: Kind
    let anchorDate: Date
    let fireDate: Date
    let title: String
    let body: String

    /// One awareness can be currency-scoped (Phase 8 honesty — never mixes
    /// currencies into a single message; one payload per currency).
    let currencyCode: String?

    /// `awareness.{kind}.{anchorYYYY-MM-dd}[.{currency}]`
    var identifier: String {
        let key = NotificationIdentifierFormatter.dayKey(for: anchorDate)
        let base = "\(NotificationIdentifierPrefix.awareness)\(kind.rawValue).\(key)"
        if let currencyCode { return "\(base).\(currencyCode)" }
        return base
    }

    var priority: NotificationPriority { .low }
}

// MARK: - Priority

/// Used by `NotificationSchedulingPolicy` to decide which notification gets
/// dropped when the day's throttle ceiling is reached. Higher raw value = more
/// important and kept first.
enum NotificationPriority: Int, Hashable, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Identifier formatter

/// Stable day-key used inside notification identifiers so that the same
/// (kind, day) pair always produces the same identifier — required for dedupe.
enum NotificationIdentifierFormatter {
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
