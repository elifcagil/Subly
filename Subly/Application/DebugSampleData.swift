import Foundation

/// QA wrapper around `SampleDataSeeding`: activated only by the
/// `-seedSampleData` launch argument for screenshots / visual QA. Also repairs
/// stores seeded before `Category.defaults` got stable IDs.
enum DebugSampleData {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedSampleData")
    }

    @MainActor
    static func seedIfNeeded(into container: AppContainer) async {
        guard isRequested else { return }
        let repo = container.subscriptionRepository
        let categories = (try? await container.categoryRepository.fetchAll()) ?? []
        let validCategoryIDs = Set(categories.map(\.id))

        if let existing = try? await repo.fetchAll(), !existing.isEmpty {
            // Repair data seeded before Category.defaults got stable IDs:
            // if any subscription points at a category that no longer exists,
            // wipe and re-seed so category names resolve again.
            let hasDangling = existing.contains { sub in
                sub.categoryIDs.contains { !validCategoryIDs.contains($0) }
            }
            guard hasDangling else { return }
            for sub in existing {
                try? await repo.delete(sub.id)
            }
        }
        await container.sampleDataSeeder.seedIfEmpty()
    }
}
