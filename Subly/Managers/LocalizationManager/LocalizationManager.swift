import Foundation

protocol LocalizationManaging: Sendable {
    @MainActor func currentLanguage() -> AppLanguage
    @MainActor func setLanguage(_ language: AppLanguage)
    func observe() -> AsyncStream<AppLanguage>
}

final class LocalizationManager: LocalizationManaging, @unchecked Sendable {

    private let defaultsKey = "com.subly.locale.language"
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<AppLanguage>.Continuation] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        LocalizationBundle.shared.set(language: resolveCurrentLanguage())
    }

    @MainActor
    func currentLanguage() -> AppLanguage {
        resolveCurrentLanguage()
    }

    @MainActor
    func setLanguage(_ language: AppLanguage) {
        guard language != resolveCurrentLanguage() else { return }
        defaults.set(language.rawValue, forKey: defaultsKey)
        LocalizationBundle.shared.set(language: language)
        broadcast(language)
    }

    nonisolated func observe() -> AsyncStream<AppLanguage> {
        AsyncStream { continuation in
            let token = UUID()
            self.register(token: token, continuation: continuation)
            continuation.onTermination = { @Sendable _ in
                self.unregister(token: token)
            }
        }
    }

    private func register(token: UUID, continuation: AsyncStream<AppLanguage>.Continuation) {
        lock.lock()
        continuations[token] = continuation
        lock.unlock()
        continuation.yield(resolveCurrentLanguage())
    }

    private func unregister(token: UUID) {
        lock.lock()
        continuations.removeValue(forKey: token)
        lock.unlock()
    }

    private func broadcast(_ language: AppLanguage) {
        lock.lock()
        let snapshot = Array(continuations.values)
        lock.unlock()
        for continuation in snapshot {
            continuation.yield(language)
        }
    }

    private func resolveCurrentLanguage() -> AppLanguage {
        if let raw = defaults.string(forKey: defaultsKey),
           let language = AppLanguage(rawValue: raw) {
            return language
        }
        return .systemDefault
    }
}
