import Foundation
import SwiftData

protocol SubscriptionRepository: Sendable {
    func fetchAll() async throws -> [Subscription]
    func fetchActive() async throws -> [Subscription]
    func subscription(with id: UUID) async throws -> Subscription
    func save(_ subscription: Subscription) async throws
    func archive(_ id: UUID) async throws
    func delete(_ id: UUID) async throws
    func observe() -> AsyncStream<[Subscription]>
}

@MainActor
final class SwiftDataSubscriptionRepository: SubscriptionRepository {

    private let modelContainer: ModelContainer
    private let dateProvider: DateProviding
    private var continuations: [UUID: AsyncStream<[Subscription]>.Continuation] = [:]

    init(modelContainer: ModelContainer, dateProvider: DateProviding) {
        self.modelContainer = modelContainer
        self.dateProvider = dateProvider
    }

    private var context: ModelContext { modelContainer.mainContext }

    func fetchAll() async throws -> [Subscription] {
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            sortBy: [SortDescriptor(\.nextRenewalDate, order: .forward)]
        )
        do {
            return try context.fetch(descriptor).map { $0.toDomain() }
        } catch {
            throw StorageError.readFailed
        }
    }

    func fetchActive() async throws -> [Subscription] {
        try await fetchAll().filter { !$0.isArchived }
    }

    func subscription(with id: UUID) async throws -> Subscription {
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            guard let entity = try context.fetch(descriptor).first else {
                throw StorageError.notFound
            }
            return entity.toDomain()
        } catch is StorageError {
            throw StorageError.notFound
        } catch {
            throw StorageError.readFailed
        }
    }

    func save(_ subscription: Subscription) async throws {
        let id = subscription.id
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            let now = dateProvider.now
            if let existing = try context.fetch(descriptor).first {
                existing.apply(subscription, now: now)
            } else {
                let entity = SubscriptionEntity.make(from: subscription, now: now)
                context.insert(entity)
            }
            try context.save()
            notifyObservers()
        } catch {
            throw StorageError.writeFailed
        }
    }

    func archive(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            guard let entity = try context.fetch(descriptor).first else {
                throw StorageError.notFound
            }
            entity.isArchived = true
            entity.updatedAt = dateProvider.now
            try context.save()
            notifyObservers()
        } catch is StorageError {
            throw StorageError.notFound
        } catch {
            throw StorageError.writeFailed
        }
    }

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            guard let entity = try context.fetch(descriptor).first else {
                throw StorageError.notFound
            }
            context.delete(entity)
            try context.save()
            notifyObservers()
        } catch is StorageError {
            throw StorageError.notFound
        } catch {
            throw StorageError.writeFailed
        }
    }

    nonisolated func observe() -> AsyncStream<[Subscription]> {
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

    private func register(token: UUID, continuation: AsyncStream<[Subscription]>.Continuation) {
        continuations[token] = continuation
        let snapshot = (try? fetchAllSync()) ?? []
        continuation.yield(snapshot)
    }

    private func unregister(token: UUID) {
        continuations.removeValue(forKey: token)
    }

    private func notifyObservers() {
        guard let snapshot = try? fetchAllSync() else { return }
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func fetchAllSync() throws -> [Subscription] {
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            sortBy: [SortDescriptor(\.nextRenewalDate, order: .forward)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }
}

actor InMemorySubscriptionRepository: SubscriptionRepository {

    private var storage: [UUID: Subscription] = [:]
    private var continuations: [UUID: AsyncStream<[Subscription]>.Continuation] = [:]

    func fetchAll() async throws -> [Subscription] {
        Array(storage.values).sorted { $0.nextRenewalDate < $1.nextRenewalDate }
    }

    func fetchActive() async throws -> [Subscription] {
        try await fetchAll().filter { !$0.isArchived }
    }

    func subscription(with id: UUID) async throws -> Subscription {
        guard let value = storage[id] else { throw StorageError.notFound }
        return value
    }

    func save(_ subscription: Subscription) async throws {
        storage[subscription.id] = subscription
        await notify()
    }

    func archive(_ id: UUID) async throws {
        guard var current = storage[id] else { throw StorageError.notFound }
        current.isArchived = true
        storage[id] = current
        await notify()
    }

    func delete(_ id: UUID) async throws {
        guard storage.removeValue(forKey: id) != nil else { throw StorageError.notFound }
        await notify()
    }

    nonisolated func observe() -> AsyncStream<[Subscription]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.register(token: token, continuation: continuation) }
            continuation.onTermination = { @Sendable _ in
                Task { await self.unregister(token: token) }
            }
        }
    }

    private func register(token: UUID, continuation: AsyncStream<[Subscription]>.Continuation) {
        continuations[token] = continuation
        let snapshot = Array(storage.values).sorted { $0.nextRenewalDate < $1.nextRenewalDate }
        continuation.yield(snapshot)
    }

    private func unregister(token: UUID) {
        continuations.removeValue(forKey: token)
    }

    private func notify() async {
        let snapshot = Array(storage.values).sorted { $0.nextRenewalDate < $1.nextRenewalDate }
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }
}
