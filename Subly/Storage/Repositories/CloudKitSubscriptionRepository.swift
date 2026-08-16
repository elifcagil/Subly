import Foundation

@MainActor
final class CloudKitSubscriptionRepository: SubscriptionRepository {

    private let local: SubscriptionRepository
    private let logger: Logging

    init(local: SubscriptionRepository, logger: Logging) {
        self.local = local
        self.logger = logger
    }

    func fetchAll() async throws -> [Subscription] {
        try await local.fetchAll()
    }

    func fetchActive() async throws -> [Subscription] {
        try await local.fetchActive()
    }

    func subscription(with id: UUID) async throws -> Subscription {
        try await local.subscription(with: id)
    }

    func save(_ subscription: Subscription) async throws {
        try await local.save(subscription)
        scheduleSync()
    }

    func archive(_ id: UUID) async throws {
        try await local.archive(id)
        scheduleSync()
    }

    func delete(_ id: UUID) async throws {
        try await local.delete(id)
        scheduleSync()
    }

    nonisolated func observe() -> AsyncStream<[Subscription]> {
        local.observe()
    }

    private func scheduleSync() {
        logger.info("CloudKit sync queued — implementation pending.", category: "sync")
    }
}
