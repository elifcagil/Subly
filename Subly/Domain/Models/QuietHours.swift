import Foundation

/// How a reminder is delivered (handoff `CLAUDE_CODE_PROMPT_QUIET_HOURS.md`).
enum DeliveryStyle: Equatable, Sendable {
    /// Default sound, `.active`.
    case normal
    /// No sound, `.passive`: straight to Notification Center, no banner.
    case silent
    /// Sound + `.timeSensitive` (same-day reminders outside quiet hours, or
    /// inside them with "Renewal-day alerts" on).
    case timeSensitive
}

/// Quiet hours: reminders inside the window still arrive on time, but
/// silently. Persisted as JSON in the App Group defaults.
struct QuietHours: Codable, Equatable, Sendable {
    var isEnabled: Bool = true
    var start: DateComponents = DateComponents(hour: 22, minute: 0)
    var end: DateComponents = DateComponents(hour: 8, minute: 0)
    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday), keyed by the
    /// window's start day.
    var weekdays: Set<Int> = Set(1...7)
    var renewalDayAlertsWithSound: Bool = false

    static let `default` = QuietHours()

    var startMinutes: Int { (start.hour ?? 0) * 60 + (start.minute ?? 0) }
    var endMinutes: Int { (end.hour ?? 0) * 60 + (end.minute ?? 0) }

    /// `start == end` → no window at all.
    var hasWindow: Bool { isEnabled && startMinutes != endMinutes }

    /// Length of the window in minutes (crossing midnight allowed).
    var durationMinutes: Int {
        guard hasWindow else { return 0 }
        return (endMinutes - startMinutes + 24 * 60) % (24 * 60)
    }

    /// Start inclusive, end exclusive. A window that crosses midnight
    /// (22:00–08:00) is `t >= 22:00 || t < 08:00`, and the weekday filter is
    /// keyed by the day the window started.
    func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        guard hasWindow else { return false }
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let crossesMidnight = startMinutes > endMinutes
        let inside = crossesMidnight
            ? (minutes >= startMinutes || minutes < endMinutes)
            : (minutes >= startMinutes && minutes < endMinutes)
        guard inside else { return false }
        // Which day did this window start on?
        var startDay = date
        if crossesMidnight, minutes < endMinutes, let previous = calendar.date(byAdding: .day, value: -1, to: date) {
            startDay = previous
        }
        return weekdays.contains(calendar.component(.weekday, from: startDay))
    }

    func deliveryStyle(for date: Date, isSameDay: Bool, calendar: Calendar = .current) -> DeliveryStyle {
        if isQuiet(at: date, calendar: calendar) {
            return isSameDay && renewalDayAlertsWithSound ? .timeSensitive : .silent
        }
        return isSameDay ? .timeSensitive : .normal
    }

    /// The four preset chips of the settings screen.
    static let presets: [(start: Int, end: Int)] = [(22, 8), (23, 7), (0, 9), (21, 6)]

    func matchesPreset(_ preset: (start: Int, end: Int)) -> Bool {
        startMinutes == preset.start * 60 && endMinutes == preset.end * 60
    }
}
