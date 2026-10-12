import Foundation

/// One 3-month recap: everything the story cards show. Built by
/// `RecapService`; cards without data are simply absent from `cards`.
struct Recap: Hashable, Sendable {

    enum Card: Hashable, Sendable {
        case total
        case mostExpensive
        case priceIncreases
        case longestRunning
        case summary
    }

    struct MonthBar: Hashable, Sendable {
        /// First day of the month slice.
        let monthStart: Date
        let total: Decimal
    }

    struct Comparison: Hashable, Sendable {
        /// Positive = spent more than the previous period.
        let delta: Decimal
    }

    struct TopItem: Hashable, Sendable {
        let subscription: Subscription
        /// Amount paid inside the period.
        let paid: Decimal
        /// 0…1 of the period total.
        let share: Double
    }

    struct PriceIncrease: Hashable, Sendable {
        let subscription: Subscription
        let from: Decimal
        let to: Decimal
        /// (to − from) × charges per year.
        let yearlyDelta: Decimal
    }

    struct LongestRunning: Hashable, Sendable {
        let subscription: Subscription
        let months: Int
        let totalPaid: Decimal
    }

    /// 1-based recap number (period n).
    let index: Int
    let period: DateInterval
    /// The currency the recap is expressed in (no conversion; see `RecapService`).
    let currencyCode: String
    let total: Decimal
    let subscriptionCount: Int
    let perDay: Decimal
    let monthBars: [MonthBar]
    /// nil on the first recap (nothing to compare against).
    let comparison: Comparison?
    let topItem: TopItem?
    let priceIncreases: [PriceIncrease]
    let longestRunning: LongestRunning?

    var cards: [Card] {
        var cards: [Card] = [.total]
        if topItem != nil { cards.append(.mostExpensive) }
        if !priceIncreases.isEmpty { cards.append(.priceIncreases) }
        if longestRunning != nil { cards.append(.longestRunning) }
        cards.append(.summary)
        return cards
    }
}
