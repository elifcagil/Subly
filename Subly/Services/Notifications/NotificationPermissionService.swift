import Foundation
@preconcurrency import UserNotifications

/// The two `UNUserNotificationCenter` calls the permission flow needs,
/// behind a protocol so the flow can be unit tested.
protocol NotificationAuthorizationProviding: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
}

struct SystemNotificationAuthorization: NotificationAuthorizationProviding {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
}

/// Owns the notification-permission state machine:
///
/// - **Entry prompt**: asked once, the first time the main shell appears with
///   the OS status still undetermined (`shouldPromptOnEntry`).
/// - **Granted** → the Settings "Notifications" switch turns on, reminders are
///   rebuilt and the device row in the backend is updated.
/// - **Denied** → the switch turns off; the app remembers it is waiting for
///   the user to flip the OS setting, and `refreshAfterForeground` turns the
///   switch back on the moment that happens.
///
/// UIKit-free: opening iOS Settings is the coordinator's job.
@MainActor
final class NotificationPermissionService {

    private let authorization: NotificationAuthorizationProviding
    private let preferences: SettingsPreferencesManaging
    private let reminderSync: ReminderSyncing
    private let deviceProfile: DeviceProfileSyncing
    private let defaults: UserDefaults
    private let logger: Logging

    private let promptedKey = "com.subly.notifications.entry_prompted"
    private let awaitingKey = "com.subly.notifications.awaiting_system_settings"

    init(
        authorization: NotificationAuthorizationProviding,
        preferences: SettingsPreferencesManaging,
        reminderSync: ReminderSyncing,
        deviceProfile: DeviceProfileSyncing,
        defaults: UserDefaults = .standard,
        logger: Logging
    ) {
        self.authorization = authorization
        self.preferences = preferences
        self.reminderSync = reminderSync
        self.deviceProfile = deviceProfile
        self.defaults = defaults
        self.logger = logger
    }

    // MARK: Status

    func status() async -> UNAuthorizationStatus {
        await authorization.authorizationStatus()
    }

    func isAuthorized() async -> Bool {
        Self.isAuthorized(await status())
    }

    static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        case .denied, .notDetermined: return false
        @unknown default: return false
        }
    }

    // MARK: Entry prompt

    var hasPromptedOnEntry: Bool {
        defaults.bool(forKey: promptedKey)
    }

    func shouldPromptOnEntry() async -> Bool {
        guard !hasPromptedOnEntry else { return false }
        return await status() == .notDetermined
    }

    func markPromptedOnEntry() {
        defaults.set(true, forKey: promptedKey)
    }

    // MARK: Requesting

    /// Shows the system prompt and applies the outcome. Returns whether the
    /// user allowed notifications.
    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await authorization.requestAuthorization()) ?? false
        await apply(granted: granted)
        return granted
    }

    /// Call when sending the user to iOS Settings to flip the permission; the
    /// next foreground then picks the change up.
    func markAwaitingSystemSettings() {
        defaults.set(true, forKey: awaitingKey)
    }

    var isAwaitingSystemSettings: Bool {
        defaults.bool(forKey: awaitingKey)
    }

    /// If the user went to iOS Settings and allowed notifications, turn the
    /// in-app switch on and rebuild reminders. No-op otherwise.
    func refreshAfterForeground() async {
        guard isAwaitingSystemSettings else { return }
        if await isAuthorized() {
            await apply(granted: true)
        }
    }

    /// Mirrors a permission outcome into preferences, reminders and backend.
    func apply(granted: Bool) async {
        defaults.set(!granted, forKey: awaitingKey)
        preferences.setRemindersEnabled(granted)
        await reminderSync.resync()
        await deviceProfile.setNotificationsEnabled(granted)
        logger.info("Notification permission \(granted ? "granted" : "denied").", category: "notifications")
    }

    /// Backend value = the user wants reminders *and* iOS allows them. Called
    /// after the master switch changes.
    func syncBackend() async {
        let authorized = await isAuthorized()
        let enabled = preferences.current().remindersEnabled && authorized
        await deviceProfile.setNotificationsEnabled(enabled)
    }
}
