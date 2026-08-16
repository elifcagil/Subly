import Foundation

@MainActor
final class ReminderDefaultsViewModel {

    struct Row: Hashable {
        let days: Int
        let title: String
        let isSelected: Bool
    }

    struct Snapshot: Hashable {
        let rows: [Row]
    }

    private let preferences: SettingsPreferencesManaging
    private let availableOptions: [Int] = [0, 1, 3, 7]
    private var observationTask: Task<Void, Never>?

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?

    init(preferences: SettingsPreferencesManaging) {
        self.preferences = preferences
    }

    deinit {
        observationTask?.cancel()
    }

    func start() {
        publish(selected: preferences.current().defaultReminderLeadDays)
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await value in preferences.observe() {
                if Task.isCancelled { return }
                self.publish(selected: value.defaultReminderLeadDays)
            }
        }
    }

    func toggle(_ days: Int) {
        var current = preferences.current().defaultReminderLeadDays
        if current.contains(days) {
            current.remove(days)
        } else {
            current.insert(days)
        }
        preferences.setDefaultReminderLeadDays(current)
    }

    private func publish(selected: Set<Int>) {
        let rows = availableOptions.map { days in
            Row(days: days, title: title(for: days), isSelected: selected.contains(days))
        }
        state = .loaded(Snapshot(rows: rows))
    }

    private func title(for days: Int) -> String {
        switch days {
        case 0: return Strings.Settings.remindersSameDay
        case 1: return Strings.Settings.remindersOneDay
        default: return Strings.Settings.remindersDays(days)
        }
    }
}
