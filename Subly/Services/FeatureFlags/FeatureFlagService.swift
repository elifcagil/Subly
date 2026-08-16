import Foundation

protocol FeatureFlagProviding: Sendable {
    func isEnabled(_ flag: FeatureFlag) -> Bool
    func update(entitlement: SublyEntitlement)
}

enum FeatureFlag: String, Sendable {
    case insights
    case advancedInsights
    case cloudSync
    case paywall
}

final class DefaultFeatureFlagService: FeatureFlagProviding, @unchecked Sendable {

    private let baseFlags: Set<FeatureFlag>
    private let lock = NSLock()
    private var entitlement: SublyEntitlement = .free

    init(enabledFlags: Set<FeatureFlag> = [.insights, .paywall]) {
        self.baseFlags = enabledFlags
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if baseFlags.contains(flag) { return true }

        switch flag {
        case .advancedInsights, .cloudSync:
            return isPlus
        default:
            return false
        }
    }

    func update(entitlement: SublyEntitlement) {
        lock.lock()
        self.entitlement = entitlement
        lock.unlock()
    }

    private var isPlus: Bool {
        switch entitlement {
        case .free: return false
        case .plus: return true
        }
    }
}
