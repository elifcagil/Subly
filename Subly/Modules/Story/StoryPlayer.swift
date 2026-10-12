import Foundation

/// The one story engine (Recap, What's New): which card is showing, the
/// per-card auto-advance progress and the pause state. UIKit-free.
@MainActor
final class StoryPlayer {

    struct Snapshot: Equatable {
        let count: Int
        let index: Int
        let isPaused: Bool
    }

    private static let tick: TimeInterval = 1.0 / 30.0

    let count: Int
    let cardDuration: TimeInterval
    /// `false` → the last card waits for its button (Recap summary, What's
    /// New finale).
    let lastCardAutoAdvances: Bool

    private(set) var index = 0
    private(set) var isPaused = false
    /// 0…1 of the current card's duration.
    private(set) var cardProgress: Double = 0
    private var timer: Timer?

    var onSnapshot: ((Snapshot) -> Void)?
    var onProgress: ((Double) -> Void)?
    /// The last card ran out (only when `lastCardAutoAdvances`).
    var onFinishedPlaying: (() -> Void)?

    init(count: Int, cardDuration: TimeInterval, lastCardAutoAdvances: Bool = false) {
        self.count = max(1, count)
        self.cardDuration = cardDuration
        self.lastCardAutoAdvances = lastCardAutoAdvances
    }

    var isLastCard: Bool { index == count - 1 }

    func start() {
        publish()
        restartTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func next() {
        guard !isLastCard else {
            if lastCardAutoAdvances { stop(); onFinishedPlaying?() }
            return
        }
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

    /// Advances the clock by `seconds` (what the timer does every tick;
    /// exposed so tests can drive it deterministically).
    func advance(by seconds: TimeInterval) {
        guard !isPaused else { return }
        guard !(isLastCard && !lastCardAutoAdvances) else { return }
        cardProgress = min(1, cardProgress + seconds / cardDuration)
        onProgress?(cardProgress)
        if cardProgress >= 1 { next() }
    }

    // MARK: - Timer

    private func restartTimer() {
        cardProgress = 0
        onProgress?(0)
        timer?.invalidate()
        timer = nil
        guard !(isLastCard && !lastCardAutoAdvances) else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advance(by: Self.tick) }
        }
    }

    private func publish() {
        onSnapshot?(Snapshot(count: count, index: index, isPaused: isPaused))
    }
}
