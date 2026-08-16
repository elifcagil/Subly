import Foundation

/// A window of upcoming financial pressure — total amount, count, and a
/// human-readable tone — for a single currency over a specific time horizon.
///
/// Roadmap §9.2. Tones are computed against the user's *monthly average* for
/// the same currency, so "heavy" is relative to that user's normal — not an
/// absolute number.
///
/// Phase 8 honesty preserved: one window per (horizon × currency). Currencies
/// are never mixed into a single number — anywhere.
struct FinancialLoadWindow: Hashable, Sendable {

    enum Horizon: Hashable, Sendable {
        case next24h
        case next7d
        case next30d
        case customDays(Int)

        /// Day-count used by the use case to materialise the window.
        var dayCount: Int {
            switch self {
            case .next24h: return 1
            case .next7d: return 7
            case .next30d: return 30
            case .customDays(let n): return max(n, 0)
            }
        }
    }

    /// Pressure tone — driven by the ratio of window total to the user's
    /// monthly average. Computed by the use case so it stays consistent.
    enum Tone: Hashable, Sendable {
        case light       // ratio ≤ 0.25
        case moderate    // ratio ≤ 0.60
        case heavy       // ratio ≤ 1.00
        case peak        // ratio  > 1.00

        /// Localization key suffix (`pressure.tone.{this}`).
        var localizationSuffix: String {
            switch self {
            case .light: return "light"
            case .moderate: return "moderate"
            case .heavy: return "heavy"
            case .peak: return "peak"
            }
        }
    }

    let horizon: Horizon
    let currencyCode: String
    let totalAmount: Decimal
    let subscriptionCount: Int
    let tone: Tone

    /// Single heaviest day inside the window — populated only when one day
    /// stands out. The use case suppresses this when the peak < 40% of total
    /// (rule from §9.3), so the UI can render unconditionally without
    /// reasoning about noise.
    let dailyPeak: DailyPeak?

    /// `true` when the window has no upcoming charges at all. The UI uses
    /// this to skip the card entirely (Dashboard) or render a calm "no
    /// renewals" line (FinancialLoad).
    var isEmpty: Bool { subscriptionCount == 0 }
}

/// The single heaviest day inside a `FinancialLoadWindow`.
///
/// Surfaced only when the peak is significant relative to the window total
/// (≥ 40% by current rule). When it isn't, this is `nil` on the window — the
/// UI never asks "should I show this?".
struct DailyPeak: Hashable, Sendable {
    let date: Date
    let amount: Decimal
    let count: Int
}
