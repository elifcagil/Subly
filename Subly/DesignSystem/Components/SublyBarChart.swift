import UIKit

/// v5 mini bar chart. Two uses per the handoff:
/// - Dashboard hero: 6-month chart (14pt bars, r5) with single-letter month
///   labels; current month = accent, others `chartDim`.
/// - Detail "Paid so far": 12-bar payment history; accent indices mark the
///   trailing price-increase bars.
final class SublyBarChart: UIView {

    struct ViewModel {
        struct Bar {
            /// Normalized 0…1 height.
            let value: CGFloat
            /// Single-letter label under the bar (nil = no label row).
            let label: String?
            let isAccent: Bool
        }
        let bars: [Bar]
        var barWidth: CGFloat = 14
        var barRadius: CGFloat = 5
        var gap: CGFloat = 6
        /// Accessible summary, e.g. "Monthly spend, last 6 months, July highest".
        var accessibilityLabel: String?
    }

    private var viewModel: ViewModel?
    private var barLayers: [CALayer] = []
    private let labelsStack = UIStackView()
    private var hasLabels: Bool { viewModel?.bars.contains { $0.label != nil } ?? false }
    private let labelRowHeight: CGFloat = 14

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        labelsStack.axis = .horizontal
        labelsStack.distribution = .fillEqually
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelsStack)
        NSLayoutConstraint.activate([
            labelsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            labelsStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            labelsStack.heightAnchor.constraint(equalToConstant: labelRowHeight)
        ])
    }

    func configure(with viewModel: ViewModel) {
        self.viewModel = viewModel

        labelsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        labelsStack.isHidden = !viewModel.bars.contains { $0.label != nil }
        if !labelsStack.isHidden {
            for bar in viewModel.bars {
                let label = UILabel()
                label.text = bar.label
                label.font = DesignSystem.Typography.tabLabel
                label.textColor = bar.isAccent
                    ? DesignSystem.Colors.accentText
                    : DesignSystem.Colors.textTertiary
                label.textAlignment = .center
                label.adjustsFontForContentSizeCategory = false
                labelsStack.addArrangedSubview(label)
            }
        }

        isAccessibilityElement = viewModel.accessibilityLabel != nil
        accessibilityLabel = viewModel.accessibilityLabel
        accessibilityTraits = .image

        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        guard let vm = viewModel else { return super.intrinsicContentSize }
        let width = CGFloat(vm.bars.count) * vm.barWidth + CGFloat(max(0, vm.bars.count - 1)) * vm.gap
        return CGSize(width: width, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redrawBars()
    }

    private func redrawBars() {
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        guard let vm = viewModel, !vm.bars.isEmpty, bounds.height > 0 else { return }

        let chartHeight = bounds.height - (labelsStack.isHidden ? 0 : labelRowHeight + 4)
        // Label-less charts (payment history) lead from the left edge; labeled
        // charts center each bar in its label slot.
        let startX: CGFloat = 0
        let slotWidth = labelsStack.isHidden ? (vm.barWidth + vm.gap) : bounds.width / CGFloat(vm.bars.count)

        for (index, bar) in vm.bars.enumerated() {
            let layer = CALayer()
            let height = max(4, chartHeight * min(max(bar.value, 0), 1))
            let x: CGFloat = labelsStack.isHidden
                ? startX + CGFloat(index) * slotWidth
                : slotWidth * CGFloat(index) + (slotWidth - vm.barWidth) / 2
            layer.frame = CGRect(x: x, y: chartHeight - height, width: vm.barWidth, height: height)
            layer.cornerRadius = vm.barRadius
            layer.backgroundColor = (bar.isAccent
                ? DesignSystem.Colors.accent
                : DesignSystem.Colors.chartDim).cgColor
            self.layer.addSublayer(layer)
            barLayers.append(layer)
        }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            redrawBars()
        }
    }
}
