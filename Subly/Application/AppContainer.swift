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
    let logger: Logging
    let sampleDataSeeder: SampleDataSeeding
    let deviceIdentity: DeviceIdentityProviding
    let registrationService: RegistrationService

    private var entitlementObservationTask: Task<Void, Never>?

    init() {
        let logger = ConsoleLogger()
        self.logger = logger
        let dateProvider = SystemDateProvider()
        self.dateProvider = dateProvider

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

        observeEntitlement()
        // One request per launch; the picker reads the cached result.
        Task { await catalogPriceService.refreshIfNeeded() }
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
