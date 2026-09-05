import Foundation

/// Seeds the repository with the handoff fixture set. Used by the
/// user-facing "Try with sample data" affordances (Onboarding 01, empty
/// state 12) and by the `-seedSampleData` QA launch argument.
protocol SampleDataSeeding: Sendable {
    /// Inserts the fixtures when the store is empty. No-op otherwise.
    @MainActor func seedIfEmpty() async
}

struct FixtureSampleDataSeeder: SampleDataSeeding {

    private let subscriptionRepository: SubscriptionRepository
    private let categoryRepository: CategoryRepository
    private let dateProvider: DateProviding

    init(
        subscriptionRepository: SubscriptionRepository,
        categoryRepository: CategoryRepository,
        dateProvider: DateProviding
    ) {
        self.subscriptionRepository = subscriptionRepository
        self.categoryRepository = categoryRepository
        self.dateProvider = dateProvider
    }

    /// (name, category, monthly amount, days-until-next-renewal).
    /// Monthly total of the set is exactly $102.45 (handoff fixture).
    private static let samples: [(name: String, category: String, amount: String, inDays: Int)] = [
        ("Netflix", "Streaming", "15.49", 3),
        ("ChatGPT Plus", "AI Tools", "20.00", 5),
        ("Spotify", "Music", "11.99", 8),
        ("iCloud+", "Cloud", "2.99", 12),
        ("YouTube Premium", "Streaming", "13.99", 19),
        ("Notion", "Productivity", "8.00", 22),
        ("LinkedIn Premium", "Productivity", "29.99", 26)
    ]

    @MainActor
    func seedIfEmpty() async {
        if let existing = try? await subscriptionRepository.fetchAll(), !existing.isEmpty { return }

        let categories = (try? await categoryRepository.fetchAll()) ?? []
        let categoryID: (String) -> UUID? = { name in
            categories.first { $0.name == name }?.id
        }

        let calendar = dateProvider.calendar
        let now = dateProvider.now

        for sample in Self.samples {
            let next = calendar.date(byAdding: .day, value: sample.inDays, to: now) ?? now
            let start = calendar.date(byAdding: .month, value: -1, to: next) ?? now
            let subscription = Subscription(
                name: sample.name,
                amount: Decimal(string: sample.amount) ?? 0,
                currencyCode: "USD",
                billingCycle: .monthly,
                startDate: start,
                nextRenewalDate: next,
                categoryIDs: categoryID(sample.category).map { [$0] } ?? [],
                notes: nil,
                isArchived: false,
                reminderLeadDays: [3]
            )
            try? await subscriptionRepository.save(subscription)
        }
    }
}
