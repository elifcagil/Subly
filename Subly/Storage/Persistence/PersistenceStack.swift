import Foundation
import SwiftData

enum AppGroup {
    static let identifier = "group.com.subly.app"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var storeURL: URL? {
        containerURL?.appendingPathComponent("Subly.store")
    }
}

protocol PersistenceStack: Sendable {
    @MainActor var modelContainer: ModelContainer { get }
}

final class SwiftDataPersistenceStack: PersistenceStack, @unchecked Sendable {

    @MainActor let modelContainer: ModelContainer

    @MainActor
    init(inMemory: Bool = false) throws {
        let schema = Schema([SubscriptionEntity.self])
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else if let storeURL = AppGroup.storeURL {
            configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }

        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
    }
}
