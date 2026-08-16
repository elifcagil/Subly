import Foundation
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
    private let notificationCenter: UNUserNotificationCenter
    private let storeKitService: StoreKitService
    private let authService: AuthService
    private let subscriptionRepository: SubscriptionRepository
    private let notificationScheduler: NotificationScheduling
    private let featureFlagService: FeatureFlagProviding
    private let deviceIdentity: DeviceIdentityProviding

    private var entitlement: SublyEntitlement = .free
    private var authState: AuthState = .signedOut
    private var notificationStatus: UNAuthorizationStatus = .notDetermined
    private var calendarStatus: CalendarAuthorizationStatus = .notDetermined
    private var preferencesValue: SettingsPreferences = .default

    private var preferencesObservationTask: Task<Void, Never>?
    private var currencyObservationTask: Task<Void, Never>?

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
    var onCopyDeviceID: ((String) -> Void)?
    var onErrorMessage: ((String) -> Void)?

    init(
        themeManager: ThemeManaging,
        localizationManager: LocalizationManaging,
        currencyManager: CurrencyManaging,
        preferences: SettingsPreferencesManaging,
        calendarService: CalendarService,
        notificationCenter: UNUserNotificationCenter = .current(),
        storeKitService: StoreKitService,
        authService: AuthService,
        subscriptionRepository: SubscriptionRepository,
        notificationScheduler: NotificationScheduling,
        featureFlagService: FeatureFlagProviding,
        deviceIdentity: DeviceIdentityProviding
    ) {
        self.themeManager = themeManager
        self.localizationManager = localizationManager
        self.currencyManager = currencyManager
        self.preferences = preferences
        self.calendarService = calendarService
        self.notificationCenter = notificationCenter
        self.storeKitService = storeKitService
        self.authService = authService
        self.subscriptionRepository = subscriptionRepository
        self.notificationScheduler = notificationScheduler
        self.featureFlagService = featureFlagService
        self.deviceIdentity = deviceIdentity
    }

    deinit {
        preferencesObservationTask?.cancel()
        currencyObservationTask?.cancel()
    }

    func load() {
        state = .loading
        preferencesValue = preferences.current()
        calendarStatus = calendarService.authorizationStatus()
        Task { [weak self] in
            guard let self else { return }
            self.notificationStatus = await notificationCenter.notificationSettings().authorizationStatus
            self.entitlement = await storeKitService.currentEntitlement()
            self.authState = authService.currentState()
            self.publishSnapshot()
        }
        observePreferences()
        observeCurrency()
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

    /// v5 master notifications switch: persists the preference, then cancels
    /// or reschedules every active subscription's renewal reminders.
    private func handleNotificationsToggle(isOn: Bool) {
        preferences.setRemindersEnabled(isOn)
        Task { [weak self] in
            guard let self else { return }
            if isOn, notificationStatus == .notDetermined {
                _ = try? await notificationScheduler.requestAuthorization()
                self.notificationStatus = await notificationCenter.notificationSettings().authorizationStatus
            }
            let active = (try? await subscriptionRepository.fetchActive()) ?? []
            if isOn {
                for sub in active where !sub.reminderLeadDays.isEmpty {
                    try? await notificationScheduler.schedule(for: sub, leadDays: sub.reminderLeadDays)
                }
            } else {
                for sub in active {
                    await notificationScheduler.cancel(for: sub.id)
                }
            }
            self.publishSnapshot()
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
                    action: .none
                ),
                .disclosure(
                    title: Strings.Settings.rowReminders,
                    accessory: .detail(reminderSummary()),
                    action: .openReminderDefaults
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
        var sections: [Section] = []
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
