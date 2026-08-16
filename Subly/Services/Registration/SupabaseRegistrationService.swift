import Foundation
import Supabase

/// One row per device in `public.devices`.
///
/// Keys are spelled out because the PostgREST encoder does **not** convert
/// camelCase to snake_case (only the Auth and Storage encoders do). Dates go
/// out as ISO8601, which Postgres accepts for `timestamptz`.
private struct DeviceRow: Encodable {
    let userId: UUID
    let deviceId: String
    let platform: String
    let appVersion: String?
    let osVersion: String
    let locale: String
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceId = "device_id"
        case platform
        case appVersion = "app_version"
        case osVersion = "os_version"
        case locale
        case lastSeenAt = "last_seen_at"
    }
}

/// Registers the anonymous device with Supabase.
///
/// There is no user account in Subly, so there is no `auth.uid()` to write RLS
/// against — and the anon key is public, which would leave the table readable by
/// anyone. Anonymous sign-in solves both: every device gets a real `auth.users`
/// row without collecting anything from the user, and the policies on
/// `public.devices` reduce to `auth.uid() = user_id`.
///
/// Wrap this in ``OfflineTolerantRegistrationService`` so a device that
/// registers without connectivity still gets into the app.
struct SupabaseRegistrationService: RegistrationService {

    private let client: SupabaseClient
    private let deviceIdentity: DeviceIdentityProviding

    init(client: SupabaseClient, deviceIdentity: DeviceIdentityProviding) {
        self.client = client
        self.deviceIdentity = deviceIdentity
    }

    var isRegistered: Bool { deviceIdentity.isRegistered() }

    func register(deviceId: String) async throws -> RegistrationResult {
        // Reuse the stored session when there is one (`session` refreshes an
        // expired token); otherwise mint the device's anonymous user. The SDK
        // persists the session in the Keychain, so this runs once per install.
        //
        // `currentSession` is checked first because it reads the Keychain
        // without touching the network. Going straight to `session` on a first
        // launch with no connectivity burns a full request timeout before
        // failing, doubling how long the user waits at the gate.
        let session: Session
        if client.auth.currentSession != nil, let refreshed = try? await client.auth.session {
            session = refreshed
        } else {
            session = try await client.auth.signInAnonymously()
        }

        // `user_id` is the primary key, so the upsert is idempotent — repeated
        // registrations refresh `last_seen_at` instead of piling up rows.
        let row = DeviceRow(
            userId: session.user.id,
            deviceId: deviceId,
            platform: "ios",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            locale: Locale.current.identifier,
            lastSeenAt: Date()
        )
        try await client.from("devices").upsert(row).execute()

        deviceIdentity.setRegistered(true)
        return RegistrationResult(deviceID: deviceId, registeredAt: Date())
    }
}
