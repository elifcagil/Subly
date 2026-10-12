import Foundation

/// Drives the story: which card is showing, the 6-second auto-advance
/// progress, pause state, and the share/done/review actions. UIKit-free.
@MainActor
final class RecapViewModel {

    static let cardDuration: TimeInterval = 8
    private static let tick: TimeInterval = 1.0 / 30.0

    struct Snapshot: Equatable {
        let cards: [Recap.Card]
        let index: Int
        let isPaused: Bool
    }

    let recap: Recap
    let periodLabel: String
    let currencyFormatter: CurrencyFormatting
    let calendar: Calendar

    private(set) var index = 0
    private(set) var isPaused = false
    /// 0…1 of the current card's 6 seconds.
    private(set) var cardProgress: Double = 0
    private var timer: Timer?

    var onSnapshot: ((Snapshot) -> Void)?
    var onProgress: ((Double) -> Void)?
    var onDismiss: (() -> Void)?
    var onShare: (() -> Void)?
    var onReviewSubscriptions: (() -> Void)?
    var onSeen: ((Recap) -> Void)?

    init(recap: Recap, periodLabel: String, currencyFormatter: CurrencyFormatting, calendar: Calendar) {
        self.recap = recap
        self.periodLabel = periodLabel
        self.currencyFormatter = currencyFormatter
        self.calendar = calendar
    }

    var cards: [Recap.Card] { recap.cards }
    var currentCard: Recap.Card { cards[index] }
    var isLastCard: Bool { index == cards.count - 1 }

    func start() {
        publish()
        restartTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func next() {
        guard !isLastCard else { return }
        index += 1
        publish()
        restartTimer()
    }

    func previous() {
        guard index > 0 else { return }
        index -= 1
        publish()
        restartTimer()
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        publish()
    }

    /// "Done" on the summary card: mark seen and close.
    func finish() {
        stop()
        onSeen?(recap)
        onDismiss?()
    }

    /// × or swipe-down: closing from any card still counts as seen.
    func close() {
        stop()
        onSeen?(recap)
        onDismiss?()
    }

    func share() {
        setPaused(true)
        onShare?()
    }

    func reviewSubscriptions() {
        stop()
        onSeen?(recap)
        onReviewSubscriptions?()
    }

    // MARK: - Timer

    private func restartTimer() {
        cardProgress = 0
        onProgress?(0)
        timer?.invalidate()
        // The summary card does not auto-advance (Share / Done end the story).
        guard !isLastCard else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advanceTimer() }
        }
    }

    private func advanceTimer() {
        guard !isPaused else { return }
        cardProgress = min(1, cardProgress + Self.tick / Self.cardDuration)
        onProgress?(cardProgress)
        if cardProgress >= 1 { next() }
    }

    private func publish() {
        onSnapshot?(Snapshot(cards: cards, index: index, isPaused: isPaused))
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
