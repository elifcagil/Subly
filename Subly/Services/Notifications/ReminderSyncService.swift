import UIKit

/// Single entry point for "the reminder set may be stale — rebuild it".
/// Everything that changes subscriptions or preferences calls this instead of
/// scheduling individual notifications, because grouping (one notification
/// for several renewals on the same day) only works over the full set.
protocol ReminderSyncing: Sendable {
    @MainActor func resync() async
}

@MainActor
final class ReminderSyncService: ReminderSyncing {

    private let repository: SubscriptionRepository
    private let preferences: SettingsPreferencesManaging
    private let scheduler: ReminderScheduling
    private let builder: ReminderContentBuilder
    private let acknowledgements: ReminderAcknowledgementStore
    private let quietHours: QuietHoursService
    private let dateProvider: DateProviding
    private let logger: Logging

    private var isRunning = false
    private var needsRerun = false
    private var timeChangeObserver: NSObjectProtocol?
    private var quietHoursTask: Task<Void, Never>?

    init(
        repository: SubscriptionRepository,
        preferences: SettingsPreferencesManaging,
        scheduler: ReminderScheduling,
        builder: ReminderContentBuilder,
        acknowledgements: ReminderAcknowledgementStore,
        quietHours: QuietHoursService,
        dateProvider: DateProviding,
        logger: Logging
    ) {
        self.repository = repository
        self.preferences = preferences
        self.scheduler = scheduler
        self.builder = builder
        self.acknowledgements = acknowledgements
        self.quietHours = quietHours
        self.dateProvider = dateProvider
        self.logger = logger
    }

    /// Quiet-hours changes re-add every pending reminder (same identifiers)
    /// with the right sound and interruption level.
    func startObservingQuietHours() {
        guard quietHoursTask == nil else { return }
        quietHoursTask = Task { [weak self] in
            guard let stream = self?.quietHours.observe() else { return }
            var isFirst = true
            for await _ in stream {
                if isFirst { isFirst = false; continue }
                await self?.resync()
            }
        }
    }

    deinit {
        if let timeChangeObserver {
            NotificationCenter.default.removeObserver(timeChangeObserver)
        }
        quietHoursTask?.cancel()
    }

    /// Rebuilds after a clock/time-zone change (the handoff's
    /// `significantTimeChange` trigger).
    func startObservingTimeChanges() {
        guard timeChangeObserver == nil else { return }
        timeChangeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                // A moved clock: refresh trusted time before re-planning so
                // triggers are converted with the new skew.
                await (self?.dateProvider as? TrustedDateProvider)?.sync()
                await self?.resync()
            }
        }
    }

    /// Rebuilds the next 60 days of reminders from the active subscriptions.
    /// With the master switch off, every rebuilt reminder is cancelled.
    /// Re-entrant calls coalesce into one extra pass after the current one.
    func resync() async {
        if isRunning {
            needsRerun = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        repeat {
            needsRerun = false
            await rebuild()
        } while needsRerun
    }

    private func rebuild() async {
        guard preferences.current().remindersEnabled else {
            await scheduler.replaceAll(with: [])
            return
        }
        let subscriptions = (try? await repository.fetchActive()) ?? []
        let unrelated = await scheduler.unrelatedPendingCount()
        let limit = max(0, ReminderContentBuilder.pendingRequestCap - unrelated)
        let requests = builder.plan(
            subscriptions: subscriptions,
            acknowledged: acknowledgements.acknowledged(),
            quietHours: quietHours.current(),
            now: dateProvider.now,
            limit: limit
        )
        await scheduler.replaceAll(with: requests)
        logger.debug("Reminders rebuilt: \(requests.count) request(s).", category: "notifications")
    }
}
