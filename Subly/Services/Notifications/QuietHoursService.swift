import Foundation

/// Source of truth for the quiet window. Reads/writes the App Group defaults
/// so extensions can evaluate the same window.
protocol QuietHoursService: Sendable {
    @MainActor func current() -> QuietHours
    @MainActor func set(_ value: QuietHours)
    @MainActor func isQuiet(at date: Date) -> Bool
    @MainActor func deliveryStyle(for date: Date, isSameDay: Bool) -> DeliveryStyle
    func observe() -> AsyncStream<QuietHours>
}

final class QuietHoursStore: QuietHoursService, @unchecked Sendable {

    static let key = "com.subly.quiet_hours"

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<QuietHours>.Continuation] = [:]

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    @MainActor
    func current() -> QuietHours {
        guard let data = defaults.data(forKey: Self.key),
              let value = try? JSONDecoder().decode(QuietHours.self, from: data) else { return .default }
        return value
    }

    @MainActor
    func set(_ value: QuietHours) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Self.key)
        }
        lock.lock(); let snapshot = Array(continuations.values); lock.unlock()
        snapshot.forEach { $0.yield(value) }
    }

    @MainActor
    func isQuiet(at date: Date) -> Bool { current().isQuiet(at: date, calendar: calendar) }

    @MainActor
    func deliveryStyle(for date: Date, isSameDay: Bool) -> DeliveryStyle {
        current().deliveryStyle(for: date, isSameDay: isSameDay, calendar: calendar)
    }

    nonisolated func observe() -> AsyncStream<QuietHours> {
        AsyncStream { continuation in
            let token = UUID()
            lock.lock(); continuations[token] = continuation; lock.unlock()
            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                self.lock.lock(); self.continuations.removeValue(forKey: token); self.lock.unlock()
            }
            Task { @MainActor in continuation.yield(self.current()) }
        }
    }
}
