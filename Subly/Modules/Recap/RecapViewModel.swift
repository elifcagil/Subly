import Foundation

/// Drives the Recap story on top of the shared `StoryPlayer` (8s per card,
/// the summary card waits for Share / Done) and owns the share / done /
/// review actions. UIKit-free.
@MainActor
final class RecapViewModel {

    static let cardDuration: TimeInterval = 8

    let recap: Recap
    let periodLabel: String
    let currencyFormatter: CurrencyFormatting
    let calendar: Calendar
    let player: StoryPlayer

    var onDismiss: (() -> Void)?
    var onShare: (() -> Void)?
    var onReviewSubscriptions: (() -> Void)?
    var onSeen: ((Recap) -> Void)?

    init(recap: Recap, periodLabel: String, currencyFormatter: CurrencyFormatting, calendar: Calendar) {
        self.recap = recap
        self.periodLabel = periodLabel
        self.currencyFormatter = currencyFormatter
        self.calendar = calendar
        self.player = StoryPlayer(count: recap.cards.count, cardDuration: Self.cardDuration, lastCardAutoAdvances: false)
    }

    var cards: [Recap.Card] { recap.cards }
    var index: Int { player.index }
    var currentCard: Recap.Card { cards[index] }
    var isLastCard: Bool { player.isLastCard }

    func start() { player.start() }
    func stop() { player.stop() }
    func next() { player.next() }
    func previous() { player.previous() }
    func setPaused(_ paused: Bool) { player.setPaused(paused) }

    /// "Done" on the summary card: mark seen and close.
    func finish() {
        player.stop()
        onSeen?(recap)
        onDismiss?()
    }

    /// × or swipe-down: closing from any card still counts as seen.
    func close() {
        player.stop()
        onSeen?(recap)
        onDismiss?()
    }

    func share() {
        player.setPaused(true)
        onShare?()
    }

    func reviewSubscriptions() {
        player.stop()
        onSeen?(recap)
        onReviewSubscriptions?()
    }

    // MARK: - Formatting helpers for the cards

    func amount(_ value: Decimal) -> String {
        currencyFormatter.string(from: value, currencyCode: recap.currencyCode)
    }

    func monthLetterLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date).uppercased()
    }

    func monthYearLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: date)
    }
}
