import UIKit

/// Base for every story card: vertically centred content stack, palette,
/// entrance-animation hooks.
class StoryCardView: UIView {
    let palette: RecapPalette
    let content = UIStackView()
    var animators: [RecapEntranceAnimator] = []

    /// `true` for cards drawn with `StoryIntroTheme`: the container rebuilds
    /// them (200ms crossfade) when the appearance changes.
    var followsAppearance: Bool { false }

    init(palette: RecapPalette) {
        self.palette = palette
        super.init(frame: .zero)
        content.axis = .vertical
        content.alignment = .fill
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Called once the card is on screen. Subclasses count up / fill.
    func playEntrance(reduceMotion: Bool) {}

    func stopAnimations() {
        animators.forEach { $0.cancel() }
        animators.removeAll()
    }

    func animate(duration: TimeInterval = 1.5, reduceMotion: Bool, _ update: @escaping (Double) -> Void) {
        let animator = RecapEntranceAnimator()
        animators.append(animator)
        animator.run(duration: duration, reduceMotion: reduceMotion, update: update)
    }
}

/// What a story shows: card count/timing (via `player`), chrome copy, the
/// per-card palette and the card views themselves.
@MainActor
protocol StoryContent: AnyObject {
    var player: StoryPlayer { get }
    /// "Subly · June recap", "Subly · What's new".
    var headerTitle: String { get }
    func palette(at index: Int, theme: StoryIntroTheme) -> RecapPalette
    /// Bottom hint ("Tap to continue"); nil hides it.
    func hint(at index: Int) -> String?
    func makeCard(at index: Int, palette: RecapPalette) -> StoryCardView
    /// × or swipe down.
    func close()
}
