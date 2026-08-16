import UIKit

/// v5 Subly brand mark: a dark rounded tile (constant in both themes) holding
/// three stacked rounded bars in the lime ramp — dim olive up top rising to
/// full accent at the bottom. Used by Splash and Onboarding.
final class SublyLogoView: UIView {

    private let barColors: [UIColor] = [
        UIColor(hex: "#4A5240"),
        UIColor(hex: "#8CA85B"),
        UIColor(hex: "#C8F169")
    ]
    private var barLayers: [CALayer] = []
    private var side: CGFloat

    init(side: CGFloat = 92) {
        self.side = side
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        self.side = 92
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        // Constant dark tile — same in Light and Dark (brand, not surface).
        backgroundColor = UIColor(hex: "#15161A")
        layer.cornerCurve = .continuous
        isAccessibilityElement = true
        accessibilityLabel = "Subly"
        accessibilityTraits = .image

        for color in barColors {
            let bar = CALayer()
            bar.backgroundColor = color.cgColor
            layer.addSublayer(bar)
            barLayers.append(bar)
        }
        setSide(side)
    }

    func setSide(_ value: CGFloat) {
        side = value
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: value),
            heightAnchor.constraint(equalToConstant: value)
        ])
        layer.cornerRadius = value * (26.0 / 92.0)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 3 bars centered: width 46%, height ~9.5%, gap ~7.5% of the side.
        let barWidth = bounds.width * 0.46
        let barHeight = bounds.height * 0.095
        let gap = bounds.height * 0.075
        let totalHeight = barHeight * 3 + gap * 2
        var y = (bounds.height - totalHeight) / 2
        let x = (bounds.width - barWidth) / 2
        for bar in barLayers {
            bar.frame = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            bar.cornerRadius = barHeight / 2
            y += barHeight + gap
        }
    }
}
