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
    private let scrollView = UIScrollView()
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
        // Every pill is as wide as its title needs (plus padding). When the
        // row fits, pills stretch proportionally to fill it; when it does not
        // (five cycles on a narrow phone), the row scrolls sideways instead
        // of clipping titles.
        stack.distribution = .fillProportionally
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.clipsToBounds = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(stack)

        let fillWidth = stack.widthAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor
        )
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            fillWidth,
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
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentHuggingPriority(.defaultLow, for: .horizontal)
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
        scrollSelectedIntoView()
        if notify { onSelect?(index) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollSelectedIntoView(animated: false)
    }

    private func scrollSelectedIntoView(animated: Bool = true) {
        guard buttons.indices.contains(selectedIndex), scrollView.bounds.width > 0 else { return }
        let frame = buttons[selectedIndex].frame.insetBy(dx: -8, dy: 0)
        scrollView.scrollRectToVisible(frame, animated: animated)
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
        scrollSelectedIntoView()
        onSelect?(sender.tag)
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            applySelection()
        }
    }
}
