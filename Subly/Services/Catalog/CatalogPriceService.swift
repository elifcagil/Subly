import Foundation
import Supabase

/// A template's current price as published on the server.
struct CatalogPrice: Codable, Hashable, Sendable {
    let amount: Decimal
    let currencyCode: String
    let billingCycle: BillingCycle
}

/// Supplies up-to-date starting prices for the catalog templates.
///
/// Prices are fetched **once per launch** and kept in a local cache, so the
/// picker never waits on the network and keeps working offline with the last
/// prices it saw (or the bundled defaults on a fresh install).
protocol CatalogPriceProviding: Sendable {
    /// Cached prices keyed by the template's lowercased name.
    func prices() async -> [String: CatalogPrice]
    /// Fetches the latest prices from the server if this launch has not yet.
    func refreshIfNeeded() async
}

/// One row of `public.catalog_prices` — see `supabase/migrations`.
private struct CatalogPriceRow: Decodable {
    let name: String
    let amount: Double
    let currencyCode: String
    let billingCycle: String

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case currencyCode = "currency_code"
        case billingCycle = "billing_cycle"
    }
}

actor SupabaseCatalogPriceService: CatalogPriceProviding {

    private let client: SupabaseClient
    private let defaults: UserDefaults
    private let logger: Logging
    private var hasRefreshedThisLaunch = false
    private var inMemory: [String: CatalogPrice]?

    private static let cacheKey = "com.subly.catalog_prices.v1"
    private static let fetchedAtKey = "com.subly.catalog_prices.fetched_at"

    init(client: SupabaseClient, defaults: UserDefaults = .standard, logger: Logging) {
        self.client = client
        self.defaults = defaults
        self.logger = logger
    }

    func prices() -> [String: CatalogPrice] {
        if let inMemory { return inMemory }
        let loaded = Self.readCache(from: defaults)
        inMemory = loaded
        return loaded
    }

    func refreshIfNeeded() async {
        guard !hasRefreshedThisLaunch else { return }
        hasRefreshedThisLaunch = true
        do {
            let rows: [CatalogPriceRow] = try await client
                .from("catalog_prices")
                .select("name,amount,currency_code,billing_cycle")
                .execute()
                .value
            guard !rows.isEmpty else { return }

            var merged = prices()
            for row in rows {
                merged[row.name.lowercased()] = CatalogPrice(
                    amount: Self.decimal(from: row.amount),
                    currencyCode: row.currencyCode.uppercased(),
                    billingCycle: BillingCycle(rawValue: row.billingCycle) ?? .monthly
                )
            }
            inMemory = merged
            if let data = try? JSONEncoder().encode(merged) {
                defaults.set(data, forKey: Self.cacheKey)
                defaults.set(Date(), forKey: Self.fetchedAtKey)
            }
            logger.info("Catalog prices refreshed (\(rows.count) rows).", category: "catalog")
        } catch {
            // Offline or table not yet provisioned: keep whatever is cached.
            // Allow a retry later in this launch (e.g. next foreground).
            hasRefreshedThisLaunch = false
            logger.warning("Catalog price refresh failed: \(error)", category: "catalog")
        }
    }

    /// JSON numerics arrive as doubles; round to cents so 15.99 stays 15.99.
    private static func decimal(from value: Double) -> Decimal {
        let raw = Decimal(value)
        var rounded = Decimal()
        var source = raw
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }

    private static func readCache(from defaults: UserDefaults) -> [String: CatalogPrice] {
        guard let data = defaults.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: CatalogPrice].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
