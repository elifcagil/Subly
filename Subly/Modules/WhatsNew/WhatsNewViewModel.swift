import UIKit

/// The What's New story: 6 cards on the shared player (7s each; the finale
/// waits for its button). Marks the version seen on any dismissal.
@MainActor
final class WhatsNewViewModel: StoryContent {

    static let cardDuration: TimeInterval = 7

    let payload: WhatsNewPayload
    /// "Sep 14" — when the first recap arrives; nil when unknown.
    let firstRecapDate: String?
    let player: StoryPlayer

    var onDismiss: (() -> Void)?
    var onSeen: ((String) -> Void)?

    init(payload: WhatsNewPayload, firstRecapDate: String?) {
        self.payload = payload
        self.firstRecapDate = firstRecapDate
        self.player = StoryPlayer(count: payload.cards.count, cardDuration: Self.cardDuration, lastCardAutoAdvances: false)
    }

    /// `firstRecapDate` formatting ("MMM d" in the user's locale).
    static func formatFirstRecapDate(_ date: Date, calendar: Calendar, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    // MARK: - StoryContent

    var headerTitle: String { Strings.WhatsNew.header }

    func palette(at index: Int, theme: StoryIntroTheme) -> RecapPalette {
        switch payload.cards[index] {
        case .intro:
            return theme.palette
        case .feature(let card):
            let colors = card.gradientHex.map { UIColor(hex: $0) }
            return RecapPalette(
                background: .radial(colors: colors, center: Self.gradientCenter(for: card.visual), radii: CGSize(width: 1.25, height: 0.8)),
                ink: .white,
                secondary: UIColor(white: 1, alpha: 0.8),
                tertiary: UIColor(white: 1, alpha: 0.5),
                progressDone: UIColor(white: 1, alpha: 0.9),
                progressUpcoming: UIColor(white: 1, alpha: 0.25),
                closeBackground: UIColor(white: 1, alpha: 0.14)
            )
        case .recapFinale:
            return RecapPalette.graphite
        }
    }

    private static func gradientCenter(for visual: WhatsNewPayload.FeatureCard.Visual) -> CGPoint {
        switch visual {
        case .homeWidgets: return CGPoint(x: 0.2, y: 0)
        case .lockScreenWidgets: return CGPoint(x: 0.8, y: 0)
        case .reminders: return CGPoint(x: 0.5, y: 0)
        case .quietHours: return CGPoint(x: 0.3, y: 0)
        }
    }

    func hint(at index: Int) -> String? {
        if case .recapFinale = payload.cards[index] { return nil }
        return Strings.WhatsNew.tapToSkipAhead
    }

    func makeCard(at index: Int, palette: RecapPalette) -> StoryCardView {
        switch payload.cards[index] {
        case .intro(let features):
            return WhatsNewIntroCardView(features: features, palette: palette)
        case .feature(let card):
            return WhatsNewFeatureCardView(card: card, palette: palette)
        case .recapFinale:
            let view = WhatsNewFinaleCardView(firstRecapDate: firstRecapDate, palette: palette)
            view.onDone = { [weak self] in self?.finish() }
            return view
        }
    }

    func close() {
        finish()
    }

    /// Any way out counts as seen for this version.
    func finish() {
        player.stop()
        onSeen?(payload.version)
        onDismiss?()
    }
}
