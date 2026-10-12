import XCTest
import UserNotifications
@testable import Subly

@MainActor
final class NotificationPermissionServiceTests: XCTestCase {

    private var authorization: FakeAuthorization!
    private var preferences: RecordingPreferences!
    private var reminderSync: CountingReminderSync!
    private var deviceProfile: RecordingDeviceProfile!
    private var defaults: UserDefaults!
    private var service: NotificationPermissionService!

    override func setUp() {
        super.setUp()
        authorization = FakeAuthorization()
        preferences = RecordingPreferences()
        reminderSync = CountingReminderSync()
        deviceProfile = RecordingDeviceProfile()
        defaults = UserDefaults(suiteName: "NotificationPermissionServiceTests")!
        defaults.removePersistentDomain(forName: "NotificationPermissionServiceTests")
        service = NotificationPermissionService(
            authorization: authorization,
            preferences: preferences,
            reminderSync: reminderSync,
            deviceProfile: deviceProfile,
            defaults: defaults,
            logger: SilentLogger()
        )
    }

    func testGrantedTurnsSwitchOnRebuildsAndSyncsBackend() async {
        authorization.status = .notDetermined
        authorization.grants = true

        let granted = await service.requestPermission()

        XCTAssertTrue(granted)
        XCTAssertEqual(preferences.remindersEnabledChanges, [true])
        XCTAssertEqual(reminderSync.resyncCount, 1)
        XCTAssertEqual(deviceProfile.values, [true])
        XCTAssertFalse(service.isAwaitingSystemSettings)
    }

    func testDeniedTurnsSwitchOffAndWaitsForSystemSettings() async {
        authorization.status = .notDetermined
        authorization.grants = false

        let granted = await service.requestPermission()

        XCTAssertFalse(granted)
        XCTAssertEqual(preferences.remindersEnabledChanges, [false])
        XCTAssertEqual(deviceProfile.values, [false])
        XCTAssertTrue(service.isAwaitingSystemSettings)
    }

    func testForegroundAfterAllowingInSystemSettingsTurnsSwitchOn() async {
        service.markAwaitingSystemSettings()
        authorization.status = .authorized

        await service.refreshAfterForeground()

        XCTAssertEqual(preferences.remindersEnabledChanges, [true])
        XCTAssertEqual(reminderSync.resyncCount, 1)
        XCTAssertEqual(deviceProfile.values, [true])
        XCTAssertFalse(service.isAwaitingSystemSettings)
    }

    func testForegroundDoesNothingWhenNotWaiting() async {
        authorization.status = .authorized

        await service.refreshAfterForeground()

        XCTAssertTrue(preferences.remindersEnabledChanges.isEmpty)
        XCTAssertEqual(reminderSync.resyncCount, 0)
    }

    func testEntryPromptIsOfferedOnceWhileUndetermined() async {
        authorization.status = .notDetermined
        let before = await service.shouldPromptOnEntry()
        service.markPromptedOnEntry()
        let after = await service.shouldPromptOnEntry()

        XCTAssertTrue(before)
        XCTAssertFalse(after)
    }

    func testEntryPromptIsNotOfferedOnceDecided() async {
        authorization.status = .denied
        let denied = await service.shouldPromptOnEntry()
        authorization.status = .authorized
        let authorized = await service.shouldPromptOnEntry()

        XCTAssertFalse(denied)
        XCTAssertFalse(authorized)
    }

    func testBackendMirrorsSwitchAndPermissionTogether() async {
        authorization.status = .authorized
        preferences.remindersEnabled = false
        await service.syncBackend()

        preferences.remindersEnabled = true
        await service.syncBackend()

        authorization.status = .denied
        await service.syncBackend()

        XCTAssertEqual(deviceProfile.values, [false, true, false])
    }
}

// MARK: - Test doubles

private final class FakeAuthorization: NotificationAuthorizationProviding, @unchecked Sendable {
    var status: UNAuthorizationStatus = .notDetermined
    var grants = true

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        status = grants ? .authorized : .denied
        return grants
    }
}

private final class RecordingPreferences: SettingsPreferencesManaging, @unchecked Sendable {
    var remindersEnabled = true
    private(set) var remindersEnabledChanges: [Bool] = []

    func current() -> SettingsPreferences {
        SettingsPreferences(defaultReminderLeadDays: [1], calendarExportEnabled: false, remindersEnabled: remindersEnabled)
    }
    func setDefaultReminderLeadDays(_ days: Set<Int>) {}
    func setCalendarExportEnabled(_ enabled: Bool) {}
    func setRemindersEnabled(_ enabled: Bool) {
        remindersEnabled = enabled
        remindersEnabledChanges.append(enabled)
    }
    func observe() -> AsyncStream<SettingsPreferences> { AsyncStream { $0.finish() } }
}

private final class CountingReminderSync: ReminderSyncing, @unchecked Sendable {
    private(set) var resyncCount = 0
    func resync() async { resyncCount += 1 }
}

private final class RecordingDeviceProfile: DeviceProfileSyncing, @unchecked Sendable {
    private(set) var values: [Bool] = []
    func setNotificationsEnabled(_ enabled: Bool) async { values.append(enabled) }
    func setRegisteredAt(_ date: Date) async {}
    func setQuietHours(_ quietHours: QuietHours) async {}
}

private struct SilentLogger: Logging {
    func debug(_ message: String, category: String) {}
    func info(_ message: String, category: String) {}
    func warning(_ message: String, category: String) {}
    func error(_ message: String, category: String) {}
}
