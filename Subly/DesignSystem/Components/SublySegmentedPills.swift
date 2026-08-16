import UIKit

/// v5 segmented billing-cycle pills (screen 08): single-select; the selected
/// pill fills accent with `accentOnFill` text, others stay surface with a
/// control-stroke border. Selection change animates 150ms.
final class SublySegmentedPills: UIView {

    struct Segment {
        let title: String
    }

    var onSelect: ((Int) -> Void)?

    private(set) var selectedIndex: Int = 0
    private let stack = UIStackView()
    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
    }

    func configure(segments: [Segment], selectedIndex: Int) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        self.selectedIndex = selectedIndex

        for (index, segment) in segments.enumerated() {
            let button = UIButton(type: .custom)
            button.tag = index
            button.layer.cornerRadius = 20
            button.layer.cornerCurve = .continuous
            button.titleLabel?.font = DesignSystem.Typography.subhead
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.8
            button.setTitle(segment.title, for: .normal)
            button.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)
            button.accessibilityLabel = segment.title
            stack.addArrangedSubview(button)
            buttons.append(button)
        }
        applySelection()
    }

    func setSelectedIndex(_ index: Int, notify: Bool = false) {
        selectedIndex = index
        applySelection()
        if notify { onSelect?(index) }
    }

    private func applySelection() {
        for (index, button) in buttons.enumerated() {
            let selected = index == selectedIndex
            button.backgroundColor = selected
                ? DesignSystem.Colors.accent
                : DesignSystem.Colors.surfaceSecondary
            button.layer.borderWidth = selected ? 0 : 1
            button.layer.borderColor = DesignSystem.Colors.strokeControl.cgColor
            button.setTitleColor(
                selected ? DesignSystem.Colors.accentOnFill : DesignSystem.Colors.textSecondary,
                for: .normal
            )
            button.accessibilityTraits = selected ? [.button, .selected] : .button
        }
    }

    @objc private func didTapSegment(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        selectedIndex = sender.tag
        UIView.animate(withDuration: 0.15) { self.applySelection() }
        onSelect?(sender.tag)
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            applySelection()
        }
    }
}
