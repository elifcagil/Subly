import Foundation

struct SettingsPreferences: Equatable, Sendable {
    var defaultReminderLeadDays: Set<Int>
    var calendarExportEnabled: Bool
    /// Master switch for renewal-reminder notifications (v5 Settings toggle).
    var remindersEnabled: Bool

    static let `default` = SettingsPreferences(
        defaultReminderLeadDays: [1],
        calendarExportEnabled: false,
        remindersEnabled: true
    )
}

protocol SettingsPreferencesManaging: Sendable {
    @MainActor func current() -> SettingsPreferences
    @MainActor func setDefaultReminderLeadDays(_ days: Set<Int>)
    @MainActor func setCalendarExportEnabled(_ enabled: Bool)
    @MainActor func setRemindersEnabled(_ enabled: Bool)
    func observe() -> AsyncStream<SettingsPreferences>
}

final class SettingsPreferencesManager: SettingsPreferencesManaging, @unchecked Sendable {

    private let leadDaysKey = "com.subly.preferences.default_reminder_lead_days"
    private let calendarKey = "com.subly.preferences.calendar_export_enabled"
    private let remindersKey = "com.subly.preferences.reminders_enabled"
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<SettingsPreferences>.Continuation] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    @MainActor
    func current() -> SettingsPreferences {
        resolve()
    }

    @MainActor
    func setDefaultReminderLeadDays(_ days: Set<Int>) {
        let sorted = Array(days).sorted()
        defaults.set(sorted, forKey: leadDaysKey)
        broadcast(resolve())
    }

    @MainActor
    func setCalendarExportEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: calendarKey)
        broadcast(resolve())
    }

    @MainActor
    func setRemindersEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: remindersKey)
        broadcast(resolve())
    }

    nonisolated func observe() -> AsyncStream<SettingsPreferences> {
        AsyncStream { continuation in
            let token = UUID()
            self.register(token: token, continuation: continuation)
            continuation.onTermination = { @Sendable _ in
                self.unregister(token: token)
            }
        }
    }

    private func register(token: UUID, continuation: AsyncStream<SettingsPreferences>.Continuation) {
        lock.lock()
        continuations[token] = continuation
        lock.unlock()
        Task { @MainActor in
            continuation.yield(resolve())
        }
    }

    private func unregister(token: UUID) {
        lock.lock()
        continuations.removeValue(forKey: token)
        lock.unlock()
    }

    private func broadcast(_ value: SettingsPreferences) {
        lock.lock()
        let snapshot = Array(continuations.values)
        lock.unlock()
        for continuation in snapshot {
            continuation.yield(value)
        }
    }

    private func resolve() -> SettingsPreferences {
        let stored = defaults.array(forKey: leadDaysKey) as? [Int]
        let leadDays = stored.map(Set.init) ?? SettingsPreferences.default.defaultReminderLeadDays
        let calendarEnabled = defaults.object(forKey: calendarKey) as? Bool ?? false
        let remindersEnabled = defaults.object(forKey: remindersKey) as? Bool
            ?? SettingsPreferences.default.remindersEnabled
        return SettingsPreferences(
            defaultReminderLeadDays: leadDays,
            calendarExportEnabled: calendarEnabled,
            remindersEnabled: remindersEnabled
        )
    }
}
