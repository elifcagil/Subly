import UIKit

/// Per-card colours. Story cards keep their colours in both appearances,
/// except the intro cards, which follow `StoryIntroTheme`.
struct RecapPalette {
    enum Background {
        case solid(UIColor)
        /// CSS-style radial gradient: colours, ellipse centre (unit) and radii (unit).
        case radial(colors: [UIColor], center: CGPoint, radii: CGSize)
    }

    let background: Background
    let ink: UIColor
    let secondary: UIColor
    let tertiary: UIColor
    /// Highlight (current month bar, comparison line).
    let accent: UIColor
    /// Dimmed fills (previous month bars).
    let muted: UIColor
    let progressDone: UIColor
    let progressUpcoming: UIColor
    let closeBackground: UIColor
    let prefersLightStatusBar: Bool

    init(
        background: Background,
        ink: UIColor,
        secondary: UIColor,
        tertiary: UIColor,
        accent: UIColor? = nil,
        muted: UIColor? = nil,
        progressDone: UIColor? = nil,
        progressUpcoming: UIColor? = nil,
        closeBackground: UIColor? = nil,
        prefersLightStatusBar: Bool = true
    ) {
        self.background = background
        self.ink = ink
        self.secondary = secondary
        self.tertiary = tertiary
        self.accent = accent ?? ink
        self.muted = muted ?? ink.withAlphaComponent(0.16)
        self.progressDone = progressDone ?? ink.withAlphaComponent(0.9)
        self.progressUpcoming = progressUpcoming ?? ink.withAlphaComponent(0.2)
        self.closeBackground = closeBackground ?? ink.withAlphaComponent(0.12)
        self.prefersLightStatusBar = prefersLightStatusBar
    }

    /// Card colours inside the story. Card 01 (Total) follows the system
    /// appearance; the share image's Total tile stays lime (`limeTotal`).
    static func palette(for card: Recap.Card, theme: StoryIntroTheme) -> RecapPalette {
        card == .total ? theme.palette : palette(for: card)
    }

    /// The lime Total tile of the summary / share image — the brand moment,
    /// kept in both appearances.
    static let limeTotal = RecapPalette(
        background: .solid(UIColor(hex: "#C8F169")),
        ink: UIColor(hex: "#141609"),
        secondary: UIColor(red: 20/255, green: 22/255, blue: 9/255, alpha: 0.7),
        tertiary: UIColor(red: 20/255, green: 22/255, blue: 9/255, alpha: 0.45),
        prefersLightStatusBar: false
    )

    static func palette(for card: Recap.Card) -> RecapPalette {
        switch card {
        case .total:
            return limeTotal
        case .mostExpensive:
            return RecapPalette(
                background: .radial(colors: [UIColor(hex: "#C0705A"), UIColor(hex: "#6A3448"), UIColor(hex: "#261426")],
                                    center: CGPoint(x: 0.2, y: 0), radii: CGSize(width: 1.3, height: 0.8)),
                ink: .white, secondary: UIColor(white: 1, alpha: 0.8), tertiary: UIColor(white: 1, alpha: 0.5)
            )
        case .priceIncreases:
            return RecapPalette(
                background: .radial(colors: [UIColor(hex: "#5A6FB0"), UIColor(hex: "#2E3A6A"), UIColor(hex: "#141A33")],
                                    center: CGPoint(x: 0.8, y: 0), radii: CGSize(width: 1.2, height: 0.8)),
                ink: .white, secondary: UIColor(white: 1, alpha: 0.8), tertiary: UIColor(white: 1, alpha: 0.5)
            )
        case .longestRunning:
            return RecapPalette(
                background: .radial(colors: [UIColor(hex: "#E7B65C"), UIColor(hex: "#9A5A2C"), UIColor(hex: "#2E1B12")],
                                    center: CGPoint(x: 0.5, y: 0), radii: CGSize(width: 1.2, height: 0.7)),
                ink: .white, secondary: UIColor(white: 1, alpha: 0.85), tertiary: UIColor(white: 1, alpha: 0.55)
            )
        case .summary:
            return graphite
        }
    }

    /// `#16181C` with light ink (summary card, What's New feature finale).
    static let graphite = RecapPalette(
        background: .solid(UIColor(hex: "#16181C")),
        ink: UIColor(hex: "#F4F5F7"),
        secondary: UIColor(red: 235/255, green: 238/255, blue: 245/255, alpha: 0.6),
        tertiary: UIColor(red: 235/255, green: 238/255, blue: 245/255, alpha: 0.45),
        accent: UIColor(hex: "#C8F169"),
        closeBackground: UIColor(white: 1, alpha: 0.1)
    )

    func makeBackgroundLayer() -> CALayer {
        switch background {
        case .solid(let color):
            let layer = CALayer()
            layer.backgroundColor = color.cgColor
            return layer
        case .radial(let colors, let center, let radii):
            let layer = CAGradientLayer()
            layer.type = .radial
            layer.colors = colors.map(\.cgColor)
            layer.locations = [0, 0.48, 1]
            layer.startPoint = center
            layer.endPoint = CGPoint(x: center.x + radii.width, y: center.y + radii.height)
            return layer
        }
    }
}

/// Ease-out-cubic driver for count-ups and fills (~1.5s). One instance per
/// animation; keeps itself alive until the run completes.
final class RecapEntranceAnimator {

    private var displayLink: CADisplayLink?
    private var start: CFTimeInterval = 0
    private var duration: TimeInterval = 0.9
    private var update: ((Double) -> Void)?
    private var retained: RecapEntranceAnimator?

    static func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    /// With Reduce Motion the final value is applied immediately.
    func run(duration: TimeInterval = 1.5, reduceMotion: Bool, update: @escaping (Double) -> Void) {
        if reduceMotion {
            update(1)
            return
        }
        self.duration = duration
        self.update = update
        retained = self
        start = CACurrentMediaTime()
        update(0)
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
        retained = nil
    }

    @objc private func tick() {
        let x = min(1, (CACurrentMediaTime() - start) / duration)
        update?(Self.easeOutCubic(x))
        if x >= 1 { cancel() }
    }
}

enum RecapTypography {
    static func font(_ size: CGFloat, weight: UIFont.Weight, tabular: Bool = false) -> UIFont {
        DesignSystem.Typography.scaled(size, weight: weight, relativeTo: size >= 40 ? .largeTitle : (size >= 20 ? .title2 : .body), tabular: tabular)
    }

    /// Hero amount with dimmed decimals (and optional tracking).
    static func dimmedAmount(_ text: String, font: UIFont, ink: UIColor, dim: UIColor, tracking: CGFloat = 0) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: ink, .kern: tracking])
        if let range = text.rangeOfCharacter(from: CharacterSet(charactersIn: ".,"), options: .backwards),
           !text[range.upperBound...].isEmpty, text[range.upperBound...].allSatisfy(\.isNumber) {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            attributed.addAttribute(.foregroundColor, value: dim, range: NSRange(location: start, length: text.count - start))
        }
        return attributed
    }

    static func label(_ size: CGFloat, weight: UIFont.Weight, color: UIColor, tabular: Bool = false, lines: Int = 0) -> UILabel {
        let label = UILabel()
        label.font = font(size, weight: weight, tabular: tabular)
        label.textColor = color
        label.numberOfLines = lines
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}

/// Brand-tile view (colour + initial), shared by the cards and the share image.
final class RecapServiceTileView: UIView {
    init(name: String, side: CGFloat, radius: CGFloat, fontSize: CGFloat) {
        super.init(frame: .zero)
        let appearance = SublyBrandAppearance.appearance(forName: name, categoryName: nil)
        backgroundColor = appearance.background
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        let label = RecapTypography.label(fontSize, weight: .heavy, color: appearance.foreground, lines: 1)
        label.text = appearance.initial
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// Subly stack mark drawn with layers (dark tile, three lime-ramp bars).
final class RecapMarkView: UIView {
    private let bars: [CALayer] = (0..<3).map { _ in CALayer() }
    private let colors = [UIColor(hex: "#4A5240"), UIColor(hex: "#8CA85B"), UIColor(hex: "#C8F169")]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: "#1A1C21")
        layer.cornerCurve = .continuous
        for (bar, color) in zip(bars, colors) {
            bar.backgroundColor = color.cgColor
            layer.addSublayer(bar)
        }
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = bounds.width
        layer.cornerRadius = side * 0.26
        for (index, bar) in bars.enumerated() {
            let i = CGFloat(index)
            bar.frame = CGRect(x: side * (0.30 - 0.03 * i), y: side * (0.26 + 0.17 * i), width: side * 0.46, height: side * 0.15)
            bar.cornerRadius = side * 0.06
        }
    }
}
