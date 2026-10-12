import AppIntents
import WidgetKit

/// A subscription the user can pin to a Renewal Ring widget.
struct PinnedSubscription: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Subscription"
    static var defaultQuery = PinnedSubscriptionQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct PinnedSubscriptionQuery: EntityQuery {

    func entities(for identifiers: [UUID]) async throws -> [PinnedSubscription] {
        let all = try await allActive()
        let wanted = Set(identifiers)
        return all.filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PinnedSubscription] {
        try await allActive()
    }

    func defaultResult() async -> PinnedSubscription? { nil }

    @MainActor
    private func allActive() async throws -> [PinnedSubscription] {
        let provider = try SharedSubscriptionProvider.make()
        return try await provider.snapshot()
            .sorted { $0.nextRenewalDate < $1.nextRenewalDate }
            .map { PinnedSubscription(id: $0.id, name: $0.name) }
    }
}

/// Widget configuration: optional pinned subscriptions (1 for Small, up to 3
/// for Medium). Empty → the soonest renewals.
struct RenewalRingConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Renewal Rings"
    static var description = IntentDescription(
        "Choose which subscriptions to show. Leave empty to see the soonest renewals."
    )

    @Parameter(title: "Subscriptions", size: [.systemSmall: 1, .systemMedium: 3])
    var subscriptions: [PinnedSubscription]?

    var pinnedIDs: [UUID] { subscriptions?.map(\.id) ?? [] }
}
