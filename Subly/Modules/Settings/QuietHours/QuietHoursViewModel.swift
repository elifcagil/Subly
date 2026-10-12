import Foundation

/// Quiet hours screen state. Every change is persisted immediately through
/// `QuietHoursService`, which re-schedules pending reminders.
@MainActor
final class QuietHoursViewModel {

    struct Snapshot: Equatable {
        let value: QuietHours
        let startText: String
        let endText: String
        let durationText: String
        let daysText: String
        let selectedPreset: Int?
        let isEnabled: Bool
    }

    private let service: QuietHoursService
    private let deviceProfile: DeviceProfileSyncing
    private let calendar: Calendar
    private(set) var value: QuietHours

    var onSnapshot: ((Snapshot) -> Void)?

    init(service: QuietHoursService, deviceProfile: DeviceProfileSyncing, calendar: Calendar) {
        self.service = service
        self.deviceProfile = deviceProfile
        self.calendar = calendar
        self.value = service.current()
    }

    func start() { publish() }

    // MARK: - Mutations

    func setEnabled(_ enabled: Bool) { update { $0.isEnabled = enabled } }

    func setStart(minutes: Int) { update { $0.start = Self.components(minutes) } }

    func setEnd(minutes: Int) { update { $0.end = Self.components(minutes) } }

    func setRange(startMinutes: Int, endMinutes: Int) {
        update {
            $0.start = Self.components(startMinutes)
            $0.end = Self.components(endMinutes)
        }
    }

    func applyPreset(_ index: Int) {
        guard QuietHours.presets.indices.contains(index) else { return }
        let preset = QuietHours.presets[index]
        setRange(startMinutes: preset.start * 60, endMinutes: preset.end * 60)
    }

    func setWeekdays(_ weekdays: Set<Int>) {
        guard !weekdays.isEmpty else { return }
        update { $0.weekdays = weekdays }
    }

    func setRenewalDayAlerts(_ on: Bool) { update { $0.renewalDayAlertsWithSound = on } }

    private func update(_ change: (inout QuietHours) -> Void) {
        var next = value
        change(&next)
        guard next != value else { return }
        value = next
        service.set(next)
        let profile = deviceProfile
        Task { await profile.setQuietHours(next) }
        publish()
    }

    // MARK: - Formatting

    func timeText(minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    func durationText(_ quiet: QuietHours) -> String {
        let minutes = quiet.durationMinutes
        return minutes % 60 == 0
            ? Strings.QuietHours.hours(minutes / 60)
            : Strings.QuietHours.hoursMinutes(minutes / 60, minutes % 60)
    }

    func daysText(_ weekdays: Set<Int>) -> String {
        let weekend: Set<Int> = [1, 7]
        if weekdays.count == 7 { return Strings.QuietHours.everyDay }
        if weekdays == Set(2...6) { return Strings.QuietHours.weekdays }
        if weekdays == weekend { return Strings.QuietHours.weekends }
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday
        let ordered = (0..<7).map { ((first - 1 + $0) % 7) + 1 }
        return ordered.filter { weekdays.contains($0) }.map { symbols[$0 - 1] }.joined(separator: ", ")
    }

    private func publish() {
        onSnapshot?(Snapshot(
            value: value,
            startText: timeText(minutes: value.startMinutes),
            endText: timeText(minutes: value.endMinutes),
            durationText: durationText(value),
            daysText: daysText(value.weekdays),
            selectedPreset: QuietHours.presets.firstIndex { value.matchesPreset($0) },
            isEnabled: value.isEnabled
        ))
    }

    private static func components(_ minutes: Int) -> DateComponents {
        let wrapped = ((minutes % 1440) + 1440) % 1440
        return DateComponents(hour: wrapped / 60, minute: wrapped % 60)
    }

    /// Row value for the Settings list: "22:00 – 08:00" or "Off".
    static func summary(_ quiet: QuietHours, calendar: Calendar) -> String {
        guard quiet.hasWindow else { return Strings.QuietHours.off }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        func text(_ minutes: Int) -> String {
            formatter.string(from: calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date())
        }
        return "\(text(quiet.startMinutes)) – \(text(quiet.endMinutes))"
    }
}
