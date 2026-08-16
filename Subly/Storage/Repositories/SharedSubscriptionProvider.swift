import Foundation
import SwiftData

protocol SharedSubscriptionProviding: Sendable {
    func snapshot() async throws -> [Subscription]
}

@MainActor
final class SharedSubscriptionProvider: SharedSubscriptionProviding {

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    static func make() throws -> SharedSubscriptionProvider {
        let schema = Schema([SubscriptionEntity.self])
        let configuration: ModelConfiguration
        if let storeURL = AppGroup.storeURL {
            configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SharedSubscriptionProvider(modelContainer: container)
    }

    func snapshot() async throws -> [Subscription] {
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            sortBy: [SortDescriptor(\.nextRenewalDate, order: .forward)]
        )
        let entities = try modelContainer.mainContext.fetch(descriptor)
        return entities
            .map { $0.toDomain() }
            .filter { !$0.isArchived }
    }
}
