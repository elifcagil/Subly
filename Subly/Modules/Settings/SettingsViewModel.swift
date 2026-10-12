import UIKit
@preconcurrency import UserNotifications

@MainActor
final class SettingsViewModel {

    enum Row: Hashable {
        case disclosure(title: String, accessory: DisclosureAccessory, action: RowAction)
        /// `action` is `.none` for read-only rows; the device ID row uses it to
        /// copy on tap without borrowing the disclosure cell's chevron, which
        /// would wrongly suggest navigation.
        case value(title: String, detail: String, action: RowAction)
        case toggle(title: String, isOn: Bool, action: ToggleAction)
    }

    enum DisclosureAccessory: Hashable {
        case detail(String)
        case chip(text: String, tone: SublyChip.ToneKey)
        case none
    }

    enum RowAction: Hashable {
        case copyDeviceID
        case openPaywall
        case openAccount
        case openAppearance
        case openLanguage
        case openCurrency
        case openReminderDefaults
        case openQuietHours
        case openWhatsNew
        /// Permission row: not asked yet → system prompt; otherwise iOS Settings.
        case openNotificationPermission
        case none
    }

    enum ToggleAction: Hashable {
        case calendarExport
        case notifications
    }

    struct Section: Hashable {
        let title: String
        let footer: String?
        let rows: [Row]
    }

    struct Snapshot: Hashable {
        let sections: [Section]
    }

    private let themeManager: ThemeManaging
    private let localizationManager: LocalizationManaging
    private let currencyManager: CurrencyManaging
    private let preferences: SettingsPreferencesManaging
    private let calendarService: CalendarService
    private let permissionService: NotificationPermissionService
    private let reminderSync: ReminderSyncing
    private let quietHoursService: QuietHoursService
    private var quietHoursTask: Task<Void, Never>?
    private let storeKitService: StoreKitService
    private let authService: AuthService
    private let subscriptionRepository: SubscriptionRepository
    private let featureFlagService: FeatureFlagProviding
    private let deviceIdentity: DeviceIdentityProviding

    private var entitlement: SublyEntitlement = .free
    private var authState: AuthState = .signedOut
    private var notificationStatus: UNAuthorizationStatus = .notDetermined
    private var calendarStatus: CalendarAuthorizationStatus = .notDetermined
    private var preferencesValue: SettingsPreferences = .default

    private var preferencesObservationTask: Task<Void, Never>?
    private var currencyObservationTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onOpenPaywall: (() -> Void)?
    var onOpenAccount: (() -> Void)?
    var onOpenAppearance: (() -> Void)?
    var onOpenLanguage: (() -> Void)?
    var onOpenCurrency: (() -> Void)?
    var onOpenReminderDefaults: (() -> Void)?
    var onOpenQuietHours: (() -> Void)?
    var onOpenWhatsNew: (() -> Void)?
    var onCopyDeviceID: ((String) -> Void)?
    var onErrorMessage: ((String) -> Void)?
    /// The user tapped the permission row (or flipped the switch) while iOS
    /// has notifications off for Subly → coordinator offers iOS Settings.
    var onNotificationPermissionDenied: (() -> Void)?
    var onOpenSystemNotificationSettings: (() -> Void)?

    init(
        themeManager: ThemeManaging,
        localizationManager: LocalizationManaging,
        currencyManager: CurrencyManaging,
        preferences: SettingsPreferencesManaging,
        calendarService: CalendarService,
        permissionService: NotificationPermissionService,
        reminderSync: ReminderSyncing,
        quietHoursService: QuietHoursService,
        storeKitService: StoreKitService,
        authService: AuthService,
        subscriptionRepository: SubscriptionRepository,
        featureFlagService: FeatureFlagProviding,
        deviceIdentity: DeviceIdentityProviding
    ) {
        self.themeManager = themeManager
        self.localizationManager = localizationManager
        self.currencyManager = currencyManager
        self.preferences = preferences
        self.calendarService = calendarService
        self.permissionService = permissionService
        self.reminderSync = reminderSync
        self.quietHoursService = quietHoursService
        self.storeKitService = storeKitService
        self.authService = authService
        self.subscriptionRepository = subscriptionRepository
        self.featureFlagService = featureFlagService
        self.deviceIdentity = deviceIdentity
    }

    deinit {
        preferencesObservationTask?.cancel()
        currencyObservationTask?.cancel()
        quietHoursTask?.cancel()
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    func load() {
        state = .loading
        preferencesValue = preferences.current()
        calendarStatus = calendarService.authorizationStatus()
        Task { [weak self] in
            guard let self else { return }
            self.notificationStatus = await permissionService.status()
            self.entitlement = await storeKitService.currentEntitlement()
            self.authState = authService.currentState()
            self.publishSnapshot()
        }
        observePreferences()
        observeCurrency()
        observeForeground()
        observeQuietHours()
    }

    private func observeQuietHours() {
        quietHoursTask?.cancel()
        quietHoursTask = Task { [weak self] in
            guard let self else { return }
            var isFirst = true
            for await _ in quietHoursService.observe() {
                if Task.isCancelled { return }
                if isFirst { isFirst = false; continue }
                self.publishSnapshot()
            }
        }
    }

    /// The permission row reflects iOS Settings, which the user may have
    /// changed while away — re-read on every return to the foreground.
    private func observeForeground() {
        guard foregroundObserver == nil else { return }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                await self?.refreshPermissionStatus()
            }
        }
    }

    private func refreshPermissionStatus() async {
        notificationStatus = await permissionService.status()
        preferencesValue = preferences.current()
        publishSnapshot()
    }

    func didSelect(action: RowAction) {
        switch action {
        case .copyDeviceID:
            // The full identifier goes to the pasteboard, not the masked form —
            // it is what a deletion request has to quote to find the row.
            onCopyDeviceID?(deviceIdentity.deviceID())
        case .openPaywall: onOpenPaywall?()
        case .openAccount: onOpenAccount?()
        case .openAppearance: onOpenAppearance?()
        case .openLanguage: onOpenLanguage?()
        case .openCurrency: onOpenCurrency?()
        case .openReminderDefaults: onOpenReminderDefaults?()
        case .openQuietHours: onOpenQuietHours?()
        case .openWhatsNew: onOpenWhatsNew?()
        case .openNotificationPermission: handlePermissionRowTap()
        case .none: break
        }
    }

    func didToggle(action: ToggleAction, isOn: Bool) {
        switch action {
        case .calendarExport:
            handleCalendarToggle(isOn: isOn)
        case .notifications:
            handleNotificationsToggle(isOn: isOn)
        }
    }

    /// v5 master notifications switch. Turning it on needs the OS
    /// permission: not asked yet → system prompt (the outcome sets the
    /// switch); denied → switch stays off and the coordinator points to iOS
    /// Settings. Either way the reminder set is rebuilt and the backend's
    /// device row is updated.
    private func handleNotificationsToggle(isOn: Bool) {
        Task { [weak self] in
            guard let self else { return }
            if isOn {
                switch await permissionService.status() {
                case .notDetermined:
                    await permissionService.requestPermission()
                case .denied:
                    preferences.setRemindersEnabled(false)
                    permissionService.markAwaitingSystemSettings()
                    onNotificationPermissionDenied?()
                default:
                    preferences.setRemindersEnabled(true)
                    await reminderSync.resync()
                    await permissionService.syncBackend()
                }
            } else {
                preferences.setRemindersEnabled(false)
                await reminderSync.resync()
                await permissionService.syncBackend()
            }
            await self.refreshPermissionStatus()
        }
    }

    private func handlePermissionRowTap() {
        Task { [weak self] in
            guard let self else { return }
            switch await permissionService.status() {
            case .notDetermined:
                await permissionService.requestPermission()
                await self.refreshPermissionStatus()
            case .denied:
                permissionService.markAwaitingSystemSettings()
                onOpenSystemNotificationSettings?()
            default:
                onOpenSystemNotificationSettings?()
            }
        }
    }

    private func handleCalendarToggle(isOn: Bool) {
        if isOn {
            Task { [weak self] in
                guard let self else { return }
                if calendarStatus != .authorized {
                    do {
                        _ = try await calendarService.requestAccess()
                    } catch let error as UserFacingError {
                        self.onErrorMessage?(error.userMessage)
                    } catch {
                        self.onErrorMessage?(Strings.Common.somethingWentWrong)
                    }
                    self.calendarStatus = calendarService.authorizationStatus()
                }
                if self.calendarStatus == .authorized {
                    self.preferences.setCalendarExportEnabled(true)
                } else {
                    self.onErrorMessage?(Strings.Settings.calendarPermissionDenied)
                    self.publishSnapshot()
                }
            }
        } else {
            preferences.setCalendarExportEnabled(false)
        }
    }

    private func observePreferences() {
        preferencesObservationTask?.cancel()
        preferencesObservationTask = Task { [weak self] in
            guard let self else { return }
            for await value in preferences.observe() {
                if Task.isCancelled { return }
                self.preferencesValue = value
                self.publishSnapshot()
            }
        }
    }

    private func observeCurrency() {
        currencyObservationTask?.cancel()
        currencyObservationTask = Task { [weak self] in
            guard let self else { return }
            var skippedInitial = false
            for await _ in currencyManager.observe() {
                if Task.isCancelled { return }
                guard skippedInitial else { skippedInitial = true; continue }
                self.publishSnapshot()
            }
        }
    }

    private func publishSnapshot() {
        // The plan section holds both paid surfaces: Subly Plus (paywall) and
        // Account (Sign in with Apple). Both are off for the 1.0 App Store
        // release — the IAP products do not exist in App Store Connect yet, and
        // shipping Sign in with Apple would oblige us to build in-app account
        // deletion (Guideline 5.1.1(v)). Flip `.paywall` back on in
        // `AppContainer` to restore the whole section.
        let showsPlanSection = featureFlagService.isEnabled(.paywall)
        let plan = Section(
            title: Strings.Settings.sectionPlan,
            footer: nil,
            rows: [
                .disclosure(
                    title: Strings.Settings.rowSublyPlus,
                    accessory: entitlementAccessory(),
                    action: .openPaywall
                ),
                .disclosure(
                    title: Strings.Settings.rowAccount,
                    accessory: .detail(accountLabel()),
                    action: .openAccount
                )
            ]
        )
        let appearance = Section(
            title: Strings.Settings.sectionAppearance,
            footer: nil,
            rows: [
                .disclosure(
                    title: Strings.Settings.rowAppearance,
                    accessory: .detail(themeManager.currentAppearanceLabel()),
                    action: .openAppearance
                )
            ]
        )
        let language = Section(
            title: Strings.Settings.sectionLanguage,
            footer: nil,
            rows: [
                .disclosure(
                    title: Strings.Settings.rowLanguage,
                    accessory: .detail(languageLabel()),
                    action: .openLanguage
                )
            ]
        )
        let currency = Section(
            title: Strings.Settings.sectionCurrency,
            footer: Strings.Settings.currencyFooter,
            rows: [
                .disclosure(
                    title: Strings.Settings.rowCurrency,
                    accessory: .detail(currencyLabel()),
                    action: .openCurrency
                )
            ]
        )
        let notifications = Section(
            title: Strings.Settings.sectionNotifications,
            footer: Strings.Settings.notificationsFooter,
            rows: [
                .toggle(
                    title: Strings.Settings.rowNotifications,
                    isOn: preferencesValue.remindersEnabled,
                    action: .notifications
                ),
                .value(
                    title: Strings.Settings.rowPermission,
                    detail: permissionText(for: notificationStatus),
                    action: .openNotificationPermission
                ),
                .disclosure(
                    title: Strings.Settings.rowReminders,
                    accessory: .detail(reminderSummary()),
                    action: .openReminderDefaults
                ),
                .disclosure(
                    title: Strings.QuietHours.row,
                    accessory: .detail(QuietHoursViewModel.summary(quietHoursService.current(), calendar: .current)),
                    action: .openQuietHours
                ),
                .toggle(
                    title: Strings.Settings.rowCalendarExport,
                    isOn: preferencesValue.calendarExportEnabled && calendarStatus == .authorized,
                    action: .calendarExport
                )
            ]
        )
        let about = Section(
            title: Strings.Settings.sectionAbout,
            footer: Strings.Settings.dataFooter,
            rows: [
                // No "iCloud sync — Soon" row here: App Review treats a control
                // that announces a feature the build does not have as
                // placeholder content (Guideline 2.1). Add it back when sync
                // actually ships.
                .value(title: Strings.Settings.rowVersion, detail: Self.appVersion, action: .none),
                // Shown so a user can quote it when asking us to delete their
                // device record — the row is anonymous, so it is the only way
                // to identify which one is theirs. Tapping copies the full ID.
                .value(
                    title: Strings.Settings.rowDeviceID,
                    detail: deviceIdentity.displayID(),
                    action: .copyDeviceID
                )
            ]
        )
        // First group: re-open this version's What's New story (only while
        // `WhatsNewPayload.isEnabled` is on for a release).
        let updates = Section(
            title: Strings.WhatsNew.settingsSection,
            footer: nil,
            rows: [
                .disclosure(
                    title: Strings.WhatsNew.settingsRow,
                    accessory: .detail(AppVersion.current),
                    action: .openWhatsNew
                )
            ]
        )
        var sections: [Section] = []
        if WhatsNewPayload.active != nil { sections.append(updates) }
        if showsPlanSection { sections.append(plan) }
        sections.append(contentsOf: [appearance, language, currency, notifications, about])
        state = .loaded(Snapshot(sections: sections))
    }

    private func entitlementAccessory() -> DisclosureAccessory {
        switch entitlement {
        case .free:
            return .chip(text: Strings.Settings.planUpgrade, tone: .neutral)
        case .plus:
            return .chip(text: Strings.Settings.planActive, tone: .accent)
        }
    }

    private func accountLabel() -> String {
        switch authState {
        case .signedOut: return Strings.Settings.notSignedIn
        case .signedIn(_, let name, let email):
            return name ?? email ?? Strings.Account.signedInFallback
        }
    }

    private func languageLabel() -> String {
        switch localizationManager.currentLanguage() {
        case .english: return Strings.Language.english
        case .turkish: return Strings.Language.turkish
        }
    }

    private func currencyLabel() -> String {
        let currency = currencyManager.preferredDisplayCurrency
        return "\(currency.code)  \(currency.symbol)"
    }

    private func permissionText(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return Strings.Settings.permissionEnabled
        case .denied: return Strings.Settings.permissionDisabled
        case .notDetermined: return Strings.Settings.permissionNotRequested
        @unknown default: return Strings.Settings.permissionUnknown
        }
    }

    private func reminderSummary() -> String {
        let sorted = preferencesValue.defaultReminderLeadDays.sorted()
        guard !sorted.isEmpty else { return Strings.Settings.remindersOff }
        let labels = sorted.map(reminderLabel(for:))
        switch labels.count {
        case 1: return labels[0]
        case 2: return Strings.Settings.remindersSummaryTwo(labels[0], labels[1])
        default:
            return Strings.Settings.remindersSummaryMore(labels[0], labels[1], extra: labels.count - 2)
        }
    }

    private func reminderLabel(for days: Int) -> String {
        switch days {
        case 0: return Strings.Settings.remindersSameDay
        case 1: return Strings.Settings.remindersOneDay
        default: return Strings.Settings.remindersDays(days)
        }
    }

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

extension SublyChip {
    enum ToneKey: Hashable, Sendable {
        case neutral
        case accent
        case warning
        case danger

        var tone: SublyChip.Tone {
            switch self {
            case .neutral: return .neutral
            case .accent: return .accent
            case .warning: return .warning
            case .danger: return .danger
            }
        }
    }
}
