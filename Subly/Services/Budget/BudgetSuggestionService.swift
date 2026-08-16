import Foundation

/// Future-readiness for budget targets and spending limits.
///
/// Roadmap §9.9. Phase 9 ships only the protocol + a no-op default. A future
/// phase will wire this to the Pressure section and emit suggestions like
/// *"Most users in your spend range cap subscriptions at 10% of income"*.
/// The shape stays per-currency, in keeping with Phase 8 honesty.
protocol BudgetSuggesting: Sendable {
    @MainActor
    func suggestions(for profile: FinancialHabitProfile) async -> [BudgetSuggestion]
}

/// A single budget suggestion. Phase 9 does not produce any concrete kinds;
/// the type exists to give callers a stable shape.
struct BudgetSuggestion: Hashable, Sendable {
    let currencyCode: String
    let title: String
    let body: String
    let suggestedMonthlyCap: Decimal?
}

struct NoOpBudgetSuggestionService: BudgetSuggesting {
    @MainActor
    func suggestions(for profile: FinancialHabitProfile) async -> [BudgetSuggestion] { [] }
}
