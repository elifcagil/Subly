import UIKit

/// A view backed by a `CAGradientLayer`, used for the hero "coral wash" card and
/// the premium gradient. Because `CALayer` colors do not follow trait changes,
/// the layer's `colors` are re-resolved whenever the appearance changes.
final class SublyGradientView: UIView {

    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    private var startColor: UIColor = DesignSystem.Colors.heroWashStart
    private var endColor: UIColor = DesignSystem.Colors.heroWashEnd

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.cornerCurve = .continuous
    }

    /// Configures the gradient. `angle` is in degrees, clockwise from the top
    /// (handoff hero = 142°, premium = 135°).
    func configure(start: UIColor, end: UIColor, angle: CGFloat) {
        startColor = start
        endColor = end
        let radians = angle * .pi / 180
        // Map angle to unit start/end points.
        let dx = sin(radians) / 2
        let dy = -cos(radians) / 2
        gradientLayer.startPoint = CGPoint(x: 0.5 - dx, y: 0.5 - dy)
        gradientLayer.endPoint = CGPoint(x: 0.5 + dx, y: 0.5 + dy)
        applyColors()
    }

    /// Convenience for the hero coral wash.
    func configureHeroWash() {
        configure(start: DesignSystem.Colors.heroWashStart, end: DesignSystem.Colors.heroWashEnd, angle: 142)
    }

    /// Convenience for the premium gradient.
    func configurePremium() {
        configure(start: DesignSystem.Colors.premiumGradientStart, end: DesignSystem.Colors.premiumGradientEnd, angle: 135)
    }

    private func applyColors() {
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyColors()
        }
    }
}
