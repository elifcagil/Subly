import Foundation

/// A user-facing currency in Subly.
///
/// Currency is a *display* concept resolved at the boundary by `CurrencyManaging`.
/// Persistence stores only the ISO 4217 `code` — no `Currency` value ever reaches
/// the storage layer, so adding a currency to the catalog never invalidates data
/// already on disk.
struct Currency: Hashable, Sendable, Identifiable {

    /// ISO 4217 code — "TRY", "USD", "EUR", …
    let code: String

    /// Glyph displayed alongside amounts — "₺", "$", "€".
    let symbol: String

    /// Locale used when formatting amounts in this currency.
    ///
    /// Critically, this is *not* `Locale.current`. A US-dollar amount must read
    /// `$14.99` for every Subly user regardless of their device language; the
    /// surrounding copy follows `LocalizationManager`, but each amount keeps
    /// its own grouping/decimal conventions.
    let localeIdentifier: String

    /// Localized name lookup key — "currency.try", "currency.usd", …
    let displayNameKey: String

    var id: String { code }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }
}

extension Currency {

    /// The day-one curated catalog.
    ///
    /// Adding a currency is a one-line change here. Feature code never needs to
    /// know which currencies exist — it asks `CurrencyManaging.currency(for:)`.
    static let catalog: [Currency] = [
        Currency(code: "TRY", symbol: "₺", localeIdentifier: "tr_TR", displayNameKey: "currency.try"),
        Currency(code: "USD", symbol: "$", localeIdentifier: "en_US", displayNameKey: "currency.usd"),
        Currency(code: "EUR", symbol: "€", localeIdentifier: "de_DE", displayNameKey: "currency.eur"),
        Currency(code: "GBP", symbol: "£", localeIdentifier: "en_GB", displayNameKey: "currency.gbp"),
        Currency(code: "JPY", symbol: "¥", localeIdentifier: "ja_JP", displayNameKey: "currency.jpy"),
        Currency(code: "CHF", symbol: "CHF", localeIdentifier: "de_CH", displayNameKey: "currency.chf"),
        Currency(code: "CAD", symbol: "CA$", localeIdentifier: "en_CA", displayNameKey: "currency.cad"),
        Currency(code: "AUD", symbol: "A$", localeIdentifier: "en_AU", displayNameKey: "currency.aud")
    ]

    /// USD is the universal fallback when even device-locale resolution fails.
    static let fallback: Currency = catalog.first { $0.code == "USD" } ?? catalog[0]
}
