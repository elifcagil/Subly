import Foundation

// MARK: - CurrencyManaging

/// Owns the curated currency catalog and the user's preferred display currency.
///
/// `CurrencyManaging` is the only legal route between a `String` currency code
/// and a `Currency` value. Adding a currency means adding one row to the
/// catalog and one localization key — no feature module changes.
protocol CurrencyManaging: Sendable {
    @MainActor var supported: [Currency] { get }
    @MainActor var preferredDisplayCurrency: Currency { get }
    @MainActor func currency(for code: String) -> Currency?
    @MainActor func setPreferredDisplayCurrency(_ code: String)
    func observe() -> AsyncStream<Currency>
}

// MARK: - Default implementation

final class CurrencyManager: CurrencyManaging, @unchecked Sendable {

    private let defaultsKey = "com.subly.currency.preferred"
    private let defaults: UserDefaults
    private let catalog: [Currency]
    private let catalogByCode: [String: Currency]
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Currency>.Continuation] = [:]

    init(
        catalog: [Currency] = Currency.catalog,
        defaults: UserDefaults = .standard
    ) {
        self.catalog = catalog
        self.catalogByCode = Dictionary(uniqueKeysWithValues: catalog.map { ($0.code, $0) })
        self.defaults = defaults
    }

    @MainActor
    var supported: [Currency] { catalog }

    @MainActor
    var preferredDisplayCurrency: Currency {
        if let stored = defaults.string(forKey: defaultsKey),
           let currency = catalogByCode[stored] {
            return currency
        }
        if let deviceCode = Locale.current.currency?.identifier,
           let currency = catalogByCode[deviceCode] {
            return currency
        }
        return Currency.fallback
    }

    @MainActor
    func currency(for code: String) -> Currency? {
        catalogByCode[code]
    }

    @MainActor
    func setPreferredDisplayCurrency(_ code: String) {
        guard let currency = catalogByCode[code] else { return }
        let previous = preferredDisplayCurrency
        guard previous.code != currency.code else { return }
        defaults.set(currency.code, forKey: defaultsKey)
        broadcast(currency)
    }

    nonisolated func observe() -> AsyncStream<Currency> {
        AsyncStream { continuation in
            let token = UUID()
            self.register(token: token, continuation: continuation)
            continuation.onTermination = { @Sendable _ in
                self.unregister(token: token)
            }
        }
    }

    // MARK: - Subscriber registry

    private func register(token: UUID, continuation: AsyncStream<Currency>.Continuation) {
        lock.lock()
        continuations[token] = continuation
        lock.unlock()
        Task { @MainActor in
            continuation.yield(self.preferredDisplayCurrency)
        }
    }

    private func unregister(token: UUID) {
        lock.lock()
        continuations.removeValue(forKey: token)
        lock.unlock()
    }

    private func broadcast(_ currency: Currency) {
        lock.lock()
        let snapshot = Array(continuations.values)
        lock.unlock()
        for continuation in snapshot {
            continuation.yield(currency)
        }
    }
}
