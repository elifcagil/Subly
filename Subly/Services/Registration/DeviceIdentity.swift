import Foundation
import Security

/// Anonymous device identity backing the registration flow. The ID is a
/// random `UUID` generated on first access — never IDFA/IDFV — and lives in
/// the **Keychain** (`kSecAttrAccessibleAfterFirstUnlock`) so it survives
/// reinstalls where possible. No personal data is ever attached to it.
protocol DeviceIdentityProviding: Sendable {
    /// Stable anonymous device ID (creates one on first call).
    func deviceID() -> String
    /// Whether this device completed registration.
    func isRegistered() -> Bool
    func setRegistered(_ value: Bool)
    /// True when the device passed the registration gate locally but the
    /// backend has not acknowledged it yet (registered while offline). The
    /// call is retried on the next foreground until it succeeds.
    func isPendingRemoteSync() -> Bool
    func setPendingRemoteSync(_ value: Bool)
    /// Masked display form: `SUB-7F3A···9C21`.
    func displayID() -> String
}

struct KeychainDeviceIdentity: DeviceIdentityProviding {

    private let service = "com.subly.device-identity"
    private let idAccount = "device-id"
    private let registeredAccount = "device-registered"
    private let pendingSyncAccount = "device-pending-remote-sync"

    func deviceID() -> String {
        if let existing = readString(account: idAccount) {
            return existing
        }
        let fresh = UUID().uuidString
        writeString(fresh, account: idAccount)
        return fresh
    }

    func isRegistered() -> Bool {
        readString(account: registeredAccount) == "1"
    }

    func setRegistered(_ value: Bool) {
        if value {
            writeString("1", account: registeredAccount)
        } else {
            delete(account: registeredAccount)
        }
    }

    func isPendingRemoteSync() -> Bool {
        readString(account: pendingSyncAccount) == "1"
    }

    func setPendingRemoteSync(_ value: Bool) {
        if value {
            writeString("1", account: pendingSyncAccount)
        } else {
            delete(account: pendingSyncAccount)
        }
    }

    /// `SUB-` + first hex group + `···` + last hex group of the UUID.
    /// "7F3AB2C4-…-11119C21" → "SUB-7F3A···9C21".
    func displayID() -> String {
        let raw = deviceID().replacingOccurrences(of: "-", with: "")
        guard raw.count >= 8 else { return "SUB-\(raw)" }
        let head = raw.prefix(4)
        let tail = raw.suffix(4)
        return "SUB-\(head)\u{00B7}\u{00B7}\u{00B7}\(tail)"
    }

    // MARK: - Keychain plumbing

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func readString(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writeString(_ value: String, account: String) {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)
        // Try update first; add when the item does not exist yet.
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return }
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
