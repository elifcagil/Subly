import Foundation
import Supabase

/// Best-effort mirror of per-device preferences into `public.devices`.
/// Nothing in the app depends on these writes succeeding; failures are
/// logged and the next change retries.
protocol DeviceProfileSyncing: Sendable {
    func setNotificationsEnabled(_ enabled: Bool) async
    /// Mirrors the Keychain `registeredAt` (recap cadence anchor) to the backend.
    func setRegisteredAt(_ date: Date) async
    /// Quiet window + weekdays + renewal-day toggle, with the device time zone,
    /// so a future remote push can apply the same silent rule server-side.
    func setQuietHours(_ quietHours: QuietHours) async
}

struct SupabaseDeviceProfileService: DeviceProfileSyncing {

    /// Columns added by `supabase/migrations/20261012_device_notifications.sql`.
    private struct NotificationsPatch: Encodable {
        let notificationsEnabled: Bool
        let notificationsUpdatedAt: Date

        enum CodingKeys: String, CodingKey {
            case notificationsEnabled = "notifications_enabled"
            case notificationsUpdatedAt = "notifications_updated_at"
        }
    }

    private struct RegisteredAtPatch: Encodable {
        let registeredAt: Date
        enum CodingKeys: String, CodingKey { case registeredAt = "registered_at" }
    }

    private let client: SupabaseClient
    private let logger: Logging

    init(client: SupabaseClient, logger: Logging) {
        self.client = client
        self.logger = logger
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        // No session yet (registered offline, not retried) → nothing to key on.
        guard let session = client.auth.currentSession else {
            logger.debug("Skipping notifications sync — no session yet.", category: "registration")
            return
        }
        do {
            try await client
                .from("devices")
                .update(NotificationsPatch(notificationsEnabled: enabled, notificationsUpdatedAt: Date()))
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
        } catch {
            logger.warning("Notifications flag sync failed: \(error)", category: "registration")
        }
    }

    private struct QuietHoursPatch: Encodable {
        let quietHours: QuietHours
        let timeZone: String
        enum CodingKeys: String, CodingKey { case quietHours = "quiet_hours", timeZone = "time_zone" }
    }

    func setQuietHours(_ quietHours: QuietHours) async {
        guard let session = client.auth.currentSession else { return }
        do {
            try await client
                .from("devices")
                .update(QuietHoursPatch(quietHours: quietHours, timeZone: TimeZone.current.identifier))
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
        } catch {
            logger.warning("quiet_hours sync failed: \(error)", category: "registration")
        }
    }

    func setRegisteredAt(_ date: Date) async {
        guard let session = client.auth.currentSession else { return }
        do {
            try await client
                .from("devices")
                .update(RegisteredAtPatch(registeredAt: date))
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
        } catch {
            logger.warning("registered_at sync failed: \(error)", category: "registration")
        }
    }
}

struct NoOpDeviceProfileService: DeviceProfileSyncing {
    func setNotificationsEnabled(_ enabled: Bool) async {}
    func setRegisteredAt(_ date: Date) async {}
    func setQuietHours(_ quietHours: QuietHours) async {}
}
