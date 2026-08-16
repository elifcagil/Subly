import UIKit

/// v5 proportional stacked category bar (10pt tall, r5 segments, 3pt gaps)
/// using the accent-derived `categoryShades`.
final class SublyCategoryBar: UIView {

    struct Segment {
        let name: String
        /// Proportion 0…1 of the whole; segments should sum to ~1.
        let fraction: CGFloat
    }

    private var segments: [Segment] = []
    private var segmentLayers: [CALayer] = []
    private let barHeight: CGFloat = 10
    private let gap: CGFloat = 3

    func configure(with segments: [Segment]) {
        self.segments = segments
        isAccessibilityElement = true
        accessibilityTraits = .image
        accessibilityLabel = segments
            .map { "\($0.name) \(Int(($0.fraction * 100).rounded())) %" }
            .joined(separator: ", ")
        setNeedsLayout()
    }

    /// Shade for the segment at `index` — mirrors the bar's color order so
    /// legend chips can match.
    static func shade(at index: Int) -> UIColor {
        let shades = DesignSystem.Colors.categoryShades
        return shades[min(index, shades.count - 1)]
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: barHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    private func redraw() {
        segmentLayers.forEach { $0.removeFromSuperlayer() }
        segmentLayers.removeAll()
        guard !segments.isEmpty, bounds.width > 0 else { return }

        let totalGap = gap * CGFloat(segments.count - 1)
        let available = bounds.width - totalGap
        var x: CGFloat = 0
        for (index, segment) in segments.enumerated() {
            let width = max(6, available * segment.fraction)
            let layer = CALayer()
            layer.frame = CGRect(x: x, y: (bounds.height - barHeight) / 2, width: width, height: barHeight)
            layer.cornerRadius = 5
            layer.backgroundColor = Self.shade(at: index).cgColor
            self.layer.addSublayer(layer)
            segmentLayers.append(layer)
            x += width + gap
        }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            redraw()
        }
    }
}
