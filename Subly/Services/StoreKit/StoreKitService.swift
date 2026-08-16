import Foundation
import StoreKit

protocol StoreKitService: Sendable {
    @MainActor func products() async throws -> [SublyProduct]
    @MainActor func purchase(_ product: SublyProduct) async throws -> PurchaseOutcome
    @MainActor func restorePurchases() async throws
    @MainActor func currentEntitlement() async -> SublyEntitlement
    func entitlements() -> AsyncStream<SublyEntitlement>
}

struct SublyProduct: Hashable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
    let perMonthDisplayPrice: String?
    let period: String
    let periodUnit: PeriodUnit
}

enum PeriodUnit: Sendable, Hashable {
    case week
    case month
    case year
    case other
}

enum SublyEntitlement: Equatable, Sendable {
    case free
    case plus(productID: String, expirationDate: Date?)
}

enum PurchaseOutcome: Sendable {
    case success
    case userCancelled
    case pending
}

enum StoreKitServiceError: Error, UserFacingError {
    case productsUnavailable
    case purchaseFailed
    case verificationFailed

    var userMessage: String {
        switch self {
        case .productsUnavailable: return "We couldn't load Subly Plus right now. Please try again."
        case .purchaseFailed: return "The purchase didn't go through. No charge was made."
        case .verificationFailed: return "We couldn't verify your purchase. Please contact support."
        }
    }
}

@MainActor
final class AppStoreKitService: StoreKitService, @unchecked Sendable {

    private static let productIDs: Set<String> = [
        "com.subly.plus.monthly",
        "com.subly.plus.yearly"
    ]

    private var cachedProducts: [Product] = []
    private var continuations: [UUID: AsyncStream<SublyEntitlement>.Continuation] = [:]
    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = Task { [weak self] in
            await self?.observeTransactions()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func products() async throws -> [SublyProduct] {
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            cachedProducts = storeProducts.sorted { $0.price < $1.price }
            return cachedProducts.map { product in
                SublyProduct(
                    id: product.id,
                    displayName: product.displayName,
                    description: product.description,
                    displayPrice: product.displayPrice,
                    perMonthDisplayPrice: perMonthPrice(for: product),
                    period: periodLabel(for: product),
                    periodUnit: periodUnit(for: product)
                )
            }
        } catch {
            throw StoreKitServiceError.productsUnavailable
        }
    }

    func purchase(_ product: SublyProduct) async throws -> PurchaseOutcome {
        guard let storeProduct = cachedProducts.first(where: { $0.id == product.id }) else {
            _ = try await products()
            guard let refetched = cachedProducts.first(where: { $0.id == product.id }) else {
                throw StoreKitServiceError.productsUnavailable
            }
            return try await purchase(storeProduct: refetched)
        }
        return try await purchase(storeProduct: storeProduct)
    }

    private func purchase(storeProduct: Product) async throws -> PurchaseOutcome {
        do {
            let result = try await storeProduct.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                await transaction.finish()
                broadcastEntitlement()
                return .success
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .pending
            }
        } catch {
            throw StoreKitServiceError.purchaseFailed
        }
    }

    func restorePurchases() async throws {
        do {
            try await AppStore.sync()
            broadcastEntitlement()
        } catch {
            throw StoreKitServiceError.purchaseFailed
        }
    }

    func currentEntitlement() async -> SublyEntitlement {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }
            return .plus(productID: transaction.productID, expirationDate: transaction.expirationDate)
        }
        return .free
    }

    nonisolated func entitlements() -> AsyncStream<SublyEntitlement> {
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

    private func register(token: UUID, continuation: AsyncStream<SublyEntitlement>.Continuation) {
        continuations[token] = continuation
        Task { @MainActor in
            let current = await currentEntitlement()
            continuation.yield(current)
        }
    }

    private func unregister(token: UUID) {
        continuations.removeValue(forKey: token)
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await broadcastEntitlement()
        }
    }

    private func broadcastEntitlement() {
        Task { @MainActor in
            let entitlement = await currentEntitlement()
            for continuation in continuations.values {
                continuation.yield(entitlement)
            }
        }
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreKitServiceError.verificationFailed
        }
    }

    private func periodLabel(for product: Product) -> String {
        guard let subscription = product.subscription else { return "" }
        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value
        switch unit {
        case .day: return value == 1 ? "Daily" : "\(value) days"
        case .week: return value == 1 ? "Weekly" : "\(value) weeks"
        case .month: return value == 1 ? "Monthly" : "\(value) months"
        case .year: return value == 1 ? "Yearly" : "\(value) years"
        @unknown default: return ""
        }
    }

    private func periodUnit(for product: Product) -> PeriodUnit {
        guard let subscription = product.subscription else { return .other }
        switch subscription.subscriptionPeriod.unit {
        case .week: return .week
        case .month: return .month
        case .year: return .year
        default: return .other
        }
    }

    private func perMonthPrice(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }
        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value
        let totalMonths: Decimal
        switch unit {
        case .year: totalMonths = Decimal(value * 12)
        case .month where value > 1: totalMonths = Decimal(value)
        default: return nil
        }
        guard totalMonths > 0 else { return nil }
        let monthly = product.price / totalMonths
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = product.priceFormatStyle.currencyCode
        return formatter.string(from: NSDecimalNumber(decimal: monthly))
    }
}

struct NoOpStoreKitService: StoreKitService {
    func products() async throws -> [SublyProduct] { [] }
    func purchase(_ product: SublyProduct) async throws -> PurchaseOutcome { .userCancelled }
    func restorePurchases() async throws {}
    func currentEntitlement() async -> SublyEntitlement { .free }
    func entitlements() -> AsyncStream<SublyEntitlement> {
        AsyncStream { continuation in
            continuation.yield(.free)
            continuation.finish()
        }
    }
}
