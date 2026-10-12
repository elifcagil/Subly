import Foundation

/// Header story-icon state (handoff `CLAUDE_CODE_PROMPT_RECAP_STORY_ICON.md`).
/// Pure: feed it the cadence facts and the seen index.
enum RecapStoryState: Equatable, Sendable {
    /// Available and not opened yet → spinning ring.
    case ready
    /// Opened at least once; stays until the window ends → thin static ring.
    case seen

    static let windowDays = 7

    /// - Parameters:
    ///   - latestDueIndex: `RecapCadence.latestDueIndex(at: now)` (0 = none).
    ///   - recapDate: the recap date for that index.
    ///   - lastSeenIndex: highest recap index the user opened.
    /// - Returns: nil when the icon should be hidden (no recap due, or the
    ///   7-day window has passed).
    static func resolve(
        latestDueIndex: Int,
        recapDate: Date,
        lastSeenIndex: Int,
        now: Date,
        calendar: Calendar
    ) -> RecapStoryState? {
        guard latestDueIndex >= 1 else { return nil }
        guard let windowEnd = calendar.date(byAdding: .day, value: windowDays, to: recapDate), now < windowEnd else {
            return nil
        }
        return lastSeenIndex >= latestDueIndex ? .seen : .ready
    }
}
