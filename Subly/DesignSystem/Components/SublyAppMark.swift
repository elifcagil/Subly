import UIKit

/// The Subly brand mark: a coral rounded square with a centered "S". The "S"
/// uses the `surface` token so it reads white in Light and dark in Dark,
/// matching the handoff (no separate dark asset needed).
final class SublyAppMark: UIView {

    private let letterLabel = UILabel()
    private var side: CGFloat
    private var sizeConstraints: [NSLayoutConstraint] = []

    init(side: CGFloat = 88) {
        self.side = side
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        self.side = 88
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = DesignSystem.Colors.accent
        layer.cornerCurve = .continuous
        isAccessibilityElement = true
        accessibilityLabel = "Subly"

        letterLabel.text = "S"
        letterLabel.textColor = DesignSystem.Colors.surface
        letterLabel.textAlignment = .center
        letterLabel.adjustsFontForContentSizeCategory = true
        letterLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(letterLabel)
        NSLayoutConstraint.activate([
            letterLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setSide(side)
    }

    func setSide(_ value: CGFloat) {
        side = value
        NSLayoutConstraint.deactivate(sizeConstraints)
        sizeConstraints = [
            widthAnchor.constraint(equalToConstant: value),
            heightAnchor.constraint(equalToConstant: value)
        ]
        NSLayoutConstraint.activate(sizeConstraints)
        // 26pt radius at 88pt → proportional for other sizes.
        layer.cornerRadius = value * (26.0 / 88.0)
        let base = UIFont.systemFont(ofSize: round(value * 0.5), weight: .heavy)
        letterLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: base)
    }
}
