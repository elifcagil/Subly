import Foundation
import Supabase

@MainActor
final class AppContainer {

    let supabase: SupabaseClient

    let subscriptionRepository: SubscriptionRepository
    let categoryRepository: CategoryRepository
    let catalogRepository: CatalogRepository
    let catalogPriceService: CatalogPriceProviding
    let notificationManager: NotificationScheduling
    let smartReminderGenerator: SmartReminderGenerating
    let awarenessGenerator: AwarenessGenerating
    let insightEngine: InsightProviding
    let budgetSuggestionService: BudgetSuggesting
    let currencyManager: CurrencyManaging
    let currencyFormatter: CurrencyFormatting
    let themeManager: ThemeManaging
    let localizationManager: LocalizationManaging
    let settingsPreferences: SettingsPreferencesManaging
    let hapticsService: HapticsService
    let analyticsService: AnalyticsTracking
    let featureFlagService: FeatureFlagProviding
    let calendarService: CalendarService
    let storeKitService: StoreKitService
    let authService: AuthService
    let dateProvider: DateProviding
    /// Server-synced clock behind `dateProvider`.
    let trustedClock: TrustedDateProvider
    let logger: Logging
    let sampleDataSeeder: SampleDataSeeding
    let deviceIdentity: DeviceIdentityProviding
    let registrationService: RegistrationService
    let renewalRolloverService: RenewalRolloverService
    let reminderSyncService: ReminderSyncService
    let notificationPermissionService: NotificationPermissionService
    let deviceProfileService: DeviceProfileSyncing
    let recapScheduler: RecapScheduler
    let quietHoursService: QuietHoursService
    let whatsNewStore: WhatsNewStore

    private var entitlementObservationTask: Task<Void, Never>?

    init() {
        let logger = ConsoleLogger()
        self.logger = logger
        // "Official" time: the backend's clock, carried on a monotonic
        // counter so moving the device clock does not move renewals,
        // reminders or the recap cadence.
        let dateProvider = TrustedDateProvider()
        self.dateProvider = dateProvider
        self.trustedClock = dateProvider

        self.subscriptionRepository = Self.makeSubscriptionRepository(
            dateProvider: dateProvider,
            logger: logger
        )
        self.categoryRepository = InMemoryCategoryRepository()
        let supabase = SupabaseConfig.makeClient()
        self.supabase = supabase
        let catalogPriceService = SupabaseCatalogPriceService(client: supabase, logger: logger)
        self.catalogPriceService = catalogPriceService
        self.catalogRepository = InMemoryCatalogRepository(priceProvider: catalogPriceService)
        self.notificationManager = NotificationManager()
        self.smartReminderGenerator = RuleBasedSmartReminderGenerator()
        self.awarenessGenerator = RuleBasedAwarenessGenerator()
        self.insightEngine = NoOpInsightEngine()
        self.budgetSuggestionService = NoOpBudgetSuggestionService()
        self.currencyManager = CurrencyManager()
        self.currencyFormatter = CurrencyFormatter()
        self.themeManager = ThemeManager()
        self.localizationManager = LocalizationManager()
        self.settingsPreferences = SettingsPreferencesManager()
        self.hapticsService = SystemHapticsService()
        self.analyticsService = NoOpAnalyticsService()
        // v1.0 ships without paid surfaces: `.paywall` gates the Settings plan
        // section (Subly Plus + Account). Add `.paywall` back here to restore
        // both once the IAP products exist in App Store Connect.
        self.featureFlagService = DefaultFeatureFlagService(enabledFlags: [.insights])
        self.calendarService = EventKitCalendarService()
        self.storeKitService = AppStoreKitService()
        // Sign in with Apple is off for 1.0 — see the plan-section comment in
        // `SettingsViewModel`. Swap back to `AppleAuthService()` (and restore the
        // `com.apple.developer.applesignin` entitlement) when accounts return.
        self.authService = NoOpAuthService()
        self.sampleDataSeeder = FixtureSampleDataSeeder(
            subscriptionRepository: subscriptionRepository,
            categoryRepository: categoryRepository,
            dateProvider: dateProvider
        )
        let deviceIdentity = KeychainDeviceIdentity()
        self.deviceIdentity = deviceIdentity
        self.registrationService = OfflineTolerantRegistrationService(
            wrapping: SupabaseRegistrationService(
                client: supabase,
                deviceIdentity: deviceIdentity
            ),
            deviceIdentity: deviceIdentity,
            logger: logger
        )

        // Renewal reminders: one rebuild path for every trigger (save, delete,
        // archive, roll-forward, master switch, permission, time change).
        let reminderScheduler = LocalReminderScheduler(
            calendar: dateProvider.calendar,
            deviceDate: { [dateProvider] in dateProvider.deviceDate(for: $0) }
        )
        let reminderBuilder = ReminderContentBuilder(
            calendar: dateProvider.calendar,
            currencyFormatter: currencyFormatter
        )
        let quietHoursService = QuietHoursStore(calendar: dateProvider.calendar)
        self.quietHoursService = quietHoursService
        self.whatsNewStore = WhatsNewStore()
        let reminderSyncService = ReminderSyncService(
            repository: subscriptionRepository,
            preferences: settingsPreferences,
            scheduler: reminderScheduler,
            builder: reminderBuilder,
            acknowledgements: ReminderAcknowledgementStore(),
            quietHours: quietHoursService,
            dateProvider: dateProvider,
            logger: logger
        )
        self.reminderSyncService = reminderSyncService
        reminderSyncService.startObservingTimeChanges()
        reminderSyncService.startObservingQuietHours()

        let deviceProfileService = SupabaseDeviceProfileService(client: supabase, logger: logger)
        self.deviceProfileService = deviceProfileService
        self.notificationPermissionService = NotificationPermissionService(
            authorization: SystemNotificationAuthorization(),
            preferences: settingsPreferences,
            reminderSync: reminderSyncService,
            deviceProfile: deviceProfileService,
            logger: logger
        )

        // 3-month recap: cadence from the Keychain `registeredAt`, one
        // "Your recap is ready" notification at a time.
        let recapScheduler = RecapScheduler(
            deviceIdentity: deviceIdentity,
            repository: subscriptionRepository,
            currencyManager: currencyManager,
            currencyFormatter: currencyFormatter,
            notifications: reminderScheduler,
            builder: reminderBuilder,
            dateProvider: dateProvider,
            logger: logger
        )
        self.recapScheduler = recapScheduler
        recapScheduler.startObservingTimeChanges()

        self.renewalRolloverService = RenewalRolloverService(
            repository: subscriptionRepository,
            reminderSync: reminderSyncService,
            dateProvider: dateProvider
        )
        renewalRolloverService.startObservingDayChanges()

        observeEntitlement()
        // One request per launch; the picker reads the cached result.
        Task { await catalogPriceService.refreshIfNeeded() }
    }

    /// Advances past-due renewal dates to the next cycle (roll-forward).
    /// Called from `sceneDidBecomeActive` — covers both launch and
    /// foregrounding; day changes while open are handled by the service's
    /// own observer.
    func rollRenewalsForward() {
        let service = renewalRolloverService
        Task { await service.rollForwardExpired() }
    }

    /// Foreground pass: refresh the trusted clock first, then everything
    /// that depends on "now" (roll-forward, reminders, recap).
    func refreshTimeDependentState() {
        let clock = trustedClock
        let rollover = renewalRolloverService
        let reminders = reminderSyncService
        let recap = recapScheduler
        let profile = deviceProfileService
        let registeredAt = deviceIdentity.registeredAt()
        Task {
            await clock.sync()
            await rollover.rollForwardExpired()
            await reminders.resync()
            await recap.refresh()
            if let registeredAt { await profile.setRegisteredAt(registeredAt) }
        }
    }

    /// Rebuilds the next 60 days of renewal reminders. Called on every
    /// foreground; re-entrant calls coalesce inside the service.
    func resyncReminders() {
        let service = reminderSyncService
        Task { await service.resync() }
    }

    /// If the user allowed notifications from iOS Settings while away, turns
    /// the in-app switch on and rebuilds reminders.
    func refreshNotificationPermissionAfterForeground() {
        let service = notificationPermissionService
        Task { await service.refreshAfterForeground() }
    }

    /// Re-schedules the next "Your recap is ready" notification and mirrors
    /// the cadence anchor to the backend. Called on every foreground.
    func refreshRecap() {
        let scheduler = recapScheduler
        let profile = deviceProfileService
        let registeredAt = deviceIdentity.registeredAt()
        Task {
            await scheduler.refresh()
            if let registeredAt { await profile.setRegisteredAt(registeredAt) }
        }
    }

    /// Re-sends a registration that was completed offline. No-op in the common
    /// case; the call is idempotent, so a redundant attempt is harmless.
    func retryPendingRegistrationIfNeeded() {
        guard deviceIdentity.isPendingRemoteSync() else { return }
        let service = registrationService
        let deviceID = deviceIdentity.deviceID()
        Task { _ = try? await service.register(deviceId: deviceID) }
    }

    deinit {
        entitlementObservationTask?.cancel()
    }

    private func observeEntitlement() {
        let flagService = featureFlagService
        let storeKit = storeKitService
        entitlementObservationTask = Task {
            let stream = storeKit.entitlements()
            for await entitlement in stream {
                flagService.update(entitlement: entitlement)
            }
        }
    }

    private static func makeSubscriptionRepository(
        dateProvider: DateProviding,
        logger: Logging
    ) -> SubscriptionRepository {
        do {
            let stack = try SwiftDataPersistenceStack()
            return SwiftDataSubscriptionRepository(
                modelContainer: stack.modelContainer,
                dateProvider: dateProvider
            )
        } catch {
            logger.error("SwiftData stack failed to initialize: \(error). Falling back to in-memory store.", category: "storage")
            return InMemorySubscriptionRepository()
        }
    }
}
