import Foundation

/// A captured-but-unused snapshot of the user's subscription habits.
///
/// Roadmap §9.9 future-readiness. Phase 9 computes nothing from this struct;
/// it exists so that future phases (predictive reminders, ML insight layer,
/// budget suggestions) have a stable place to hang inferred traits without a
/// domain refactor.
///
/// The fields below are the ones most likely to be inferred first. Adding a
/// field is non-breaking: the struct is value-type and the type itself is
/// only read by future opt-in services through `InsightProviding`.
struct FinancialHabitProfile: Hashable, Sendable {

    enum BillingPreference: Hashable, Sendable {
        case monthlyDominant
        case yearlyDominant
        case mixed
        case unknown
    }

    enum SpendTrajectory: Hashable, Sendable {
        case stable
        case rising
        case falling
        case volatile
        case unknown
    }

    let billingPreference: BillingPreference
    let spendTrajectory: SpendTrajectory

    /// Set of currency codes the user actively pays in. Stable order is
    /// the caller's responsibility — this set is a snapshot, not a ranking.
    let activeCurrencyCodes: Set<String>

    /// Average monthly equivalent per currency, in plain `Decimal`. Phase 9
    /// fills this from `MonthlySpendCalculator`; future ML phases may
    /// recompute it with smoothing.
    let monthlyAverageByCurrency: [String: Decimal]

    static let empty = FinancialHabitProfile(
        billingPreference: .unknown,
        spendTrajectory: .unknown,
        activeCurrencyCodes: [],
        monthlyAverageByCurrency: [:]
    )
}
