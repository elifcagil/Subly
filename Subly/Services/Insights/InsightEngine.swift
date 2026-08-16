import Foundation

/// Umbrella protocol for future intelligence layers.
///
/// Roadmap §9.9 future-readiness. Phase 9 ships an empty/no-op default; a
/// later phase plugs in ML-backed inference behind the same interface and
/// swaps it in via `AppContainer` — feature code does not change.
///
/// The protocol intentionally exposes only one entry point: `infer(from:)`
/// returning a value. Future kinds of inference attach as additional cases
/// on `InsightKind` rather than new protocols, keeping the architecture
/// flat.
protocol InsightProviding: Sendable {
    @MainActor
    func infer(from profile: FinancialHabitProfile) async -> [Insight]
}

/// A single inferred insight. Phase 9 only models the shape — no concrete
/// kinds are implemented yet beyond a stub.
struct Insight: Hashable, Sendable {

    enum Kind: Hashable, Sendable {
        case noopPlaceholder
        // Future kinds will be added here, e.g.:
        //   case fixedDayPreference(weekday: Int, confidence: Double)
        //   case spendingSpike(month: Date, ratio: Decimal)
        //   case underusedCategory(category: String)
    }

    let kind: Kind
    let title: String
    let body: String
}

/// No-op default. Returns an empty array. Wired into `AppContainer` so the
/// rest of the app can hold an `InsightProviding` reference without nil
/// checks or feature flags.
struct NoOpInsightEngine: InsightProviding {
    @MainActor
    func infer(from profile: FinancialHabitProfile) async -> [Insight] { [] }
}
