import Foundation

// MARK: - CurrencyFormatting

/// The single source of truth for converting a `Decimal` amount into a
/// user-visible money string.
///
/// **Invariant** (`cloud.md` §7.3 sibling): no `NumberFormatter` may be
/// instantiated outside this type. Feature code asks `CurrencyFormatting`
/// for strings.
///
/// Locale is taken from the `Currency` itself, not from the device — `$14.99`
/// must render identically for a Turkish and an American user.
protocol CurrencyFormatting: Sendable {
    func string(from amount: Decimal, currencyCode: String) -> String
    func string(from amount: Decimal, currency: Currency) -> String
    func string(from amount: Decimal, currencyCode: String, locale: Locale) -> String
}

// MARK: - Default implementation

/// A thread-safe currency formatter with a per-currency cache.
///
/// `NumberFormatter` is expensive to allocate; we keep one per
/// (code, locale) pair behind a lock.
final class CurrencyFormatter: CurrencyFormatting, @unchecked Sendable {

    private struct CacheKey: Hashable {
        let code: String
        let localeIdentifier: String
    }

    private let lock = NSLock()
    private var cache: [CacheKey: NumberFormatter] = [:]
    private let currencyResolver: @Sendable (String) -> Currency?

    /// - Parameter currencyResolver: returns a catalog `Currency` for a code.
    ///   Defaults to a lookup on the day-one catalog so the formatter can be
    ///   constructed without a `CurrencyManager` (useful in widgets / intents).
    init(currencyResolver: @escaping @Sendable (String) -> Currency? = { code in
        Currency.catalog.first { $0.code == code }
    }) {
        self.currencyResolver = currencyResolver
    }

    func string(from amount: Decimal, currencyCode: String) -> String {
        let locale = currencyResolver(currencyCode)?.locale
            ?? Locale(identifier: "en_US_POSIX")
        return string(from: amount, currencyCode: currencyCode, locale: locale)
    }

    func string(from amount: Decimal, currency: Currency) -> String {
        string(from: amount, currencyCode: currency.code, locale: currency.locale)
    }

    func string(from amount: Decimal, currencyCode: String, locale: Locale) -> String {
        let formatter = cachedFormatter(code: currencyCode, locale: locale)
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "\(number) \(currencyCode)"
    }

    // MARK: - Cache

    private func cachedFormatter(code: String, locale: Locale) -> NumberFormatter {
        let key = CacheKey(code: code, localeIdentifier: locale.identifier)
        lock.lock()
        defer { lock.unlock() }
        if let existing = cache[key] {
            return existing
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true
        formatter.minimumFractionDigits = formatter.minimumFractionDigits
        cache[key] = formatter
        return formatter
    }
}
