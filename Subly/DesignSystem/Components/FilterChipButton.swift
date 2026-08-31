import UIKit

/// v5 filter chip: height 32, r16; selected = accent fill + `accentOnFill`
/// text; unselected = surface + control-stroke border. Shared by the Subs tab
/// filter row and the Dashboard currency selector.
final class FilterChipButton: UIControl {

    var onTap: (() -> Void)?

    private let label = UILabel()

    init(title: String, isSelected: Bool) {
        super.init(frame: .zero)
        configure(title: title, isSelected: isSelected)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure(title: String, isSelected: Bool) {
        layer.cornerRadius = DesignSystem.Radius.chip
        layer.cornerCurve = .continuous
        clipsToBounds = true

        if isSelected {
            backgroundColor = DesignSystem.Colors.accent
            layer.borderWidth = 0
        } else {
            backgroundColor = DesignSystem.Colors.surface
            layer.borderWidth = 1
            layer.borderColor = DesignSystem.Colors.strokeControl.cgColor
        }

        label.text = title
        label.textColor = isSelected
            ? DesignSystem.Colors.accentOnFill
            : DesignSystem.Colors.textSecondary
        label.font = DesignSystem.Typography.subhead
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false

        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])

        accessibilityLabel = title
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    @objc private func handleTap() {
        onTap?()
    }
}
