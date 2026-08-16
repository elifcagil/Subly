import UIKit

enum AppearanceMode: Int, Sendable, CaseIterable {
    case automatic = 0
    case light = 1
    case dark = 2

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .automatic: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String {
        switch self {
        case .automatic: return Strings.Appearance.automatic
        case .light: return Strings.Appearance.light
        case .dark: return Strings.Appearance.dark
        }
    }
}

protocol ThemeManaging: Sendable {
    @MainActor func currentMode() -> AppearanceMode
    @MainActor func setMode(_ mode: AppearanceMode)
    @MainActor func apply(to window: UIWindow)
    @MainActor func currentAppearanceLabel() -> String
    func observe() -> AsyncStream<AppearanceMode>
}

@MainActor
final class ThemeManager: ThemeManaging, @unchecked Sendable {

    private let defaultsKey = "com.subly.theme.mode"
    private let defaults: UserDefaults
    private var continuations: [UUID: AsyncStream<AppearanceMode>.Continuation] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentMode() -> AppearanceMode {
        let raw = defaults.integer(forKey: defaultsKey)
        return AppearanceMode(rawValue: raw) ?? .automatic
    }

    func setMode(_ mode: AppearanceMode) {
        guard mode != currentMode() else { return }
        defaults.set(mode.rawValue, forKey: defaultsKey)
        broadcast(mode)
    }

    func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = currentMode().interfaceStyle
    }

    func currentAppearanceLabel() -> String {
        currentMode().label
    }

    nonisolated func observe() -> AsyncStream<AppearanceMode> {
        AsyncStream { continuation in
            let token = UUID()
            Task { @MainActor in
                self.register(token: token, continuation: continuation)
            }
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.unregister(token: token)
                }
            }
        }
    }

    private func register(token: UUID, continuation: AsyncStream<AppearanceMode>.Continuation) {
        continuations[token] = continuation
        continuation.yield(currentMode())
    }

    private func unregister(token: UUID) {
        continuations.removeValue(forKey: token)
    }

    private func broadcast(_ mode: AppearanceMode) {
        for continuation in continuations.values {
            continuation.yield(mode)
        }
    }
}
