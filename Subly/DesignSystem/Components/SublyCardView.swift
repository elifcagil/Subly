import UIKit

/// v5 card: a `surface` fill with a 20pt continuous-corner radius and a
/// hairline border (dark relies on borders, not shadows).
final class SublyCardView: UIView {

    enum Style {
        /// Standard surface card with hairline border.
        case surface
        /// Accent-tint card (e.g. live-impact footer).
        case accentTint
    }

    var style: Style = .surface {
        didSet { applyStyle() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        layer.cornerRadius = DesignSystem.Radius.card
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        applyStyle()
    }

    private func applyStyle() {
        switch style {
        case .surface:
            backgroundColor = DesignSystem.Colors.surface
            layer.borderColor = DesignSystem.Colors.hairline.cgColor
        case .accentTint:
            backgroundColor = DesignSystem.Colors.accentTint
            layer.borderColor = UIColor.clear.cgColor
        }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            applyStyle()
        }
    }
}
