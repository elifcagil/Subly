import UIKit

/// v5 floating tab bar: a blurred pill (58pt, r29) with 4 items, plus a
/// separate circular accent FAB rendered by the owner next to it. Active item
/// tints `accentText` (olive in Light, lime in Dark); inactive = secondary ink.
final class SublyTabBar: UIView {

    struct Item {
        let title: String
        let systemIcon: String
    }

    var onSelect: ((Int) -> Void)?

    private(set) var selectedIndex: Int = 0
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let stack = UIStackView()
    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        layer.cornerRadius = DesignSystem.Radius.bar
        layer.cornerCurve = .continuous
        clipsToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 12)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = DesignSystem.Radius.bar
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        addSubview(blurView)

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    func configure(items: [Item], selectedIndex: Int = 0) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()

        for (index, item) in items.enumerated() {
            let button = UIButton(type: .custom)
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: item.systemIcon)
            config.title = item.title
            config.imagePlacement = .top
            config.imagePadding = 2
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var out = attrs
                out.font = DesignSystem.Typography.tabLabel
                return out
            }
            config.titleLineBreakMode = .byTruncatingTail
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2)
            button.configuration = config
            button.titleLabel?.numberOfLines = 1
            button.tag = index
            button.accessibilityLabel = item.title
            button.accessibilityTraits = .tabBar
            button.addTarget(self, action: #selector(didTapItem(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append(button)
        }
        setSelectedIndex(selectedIndex, notify: false)
    }

    func setSelectedIndex(_ index: Int, notify: Bool = true) {
        selectedIndex = index
        for (i, button) in buttons.enumerated() {
            let active = i == index
            button.tintColor = active
                ? DesignSystem.Colors.accentText
                : DesignSystem.Colors.textSecondary
            if active {
                button.accessibilityTraits = [.tabBar, .selected]
            } else {
                button.accessibilityTraits = .tabBar
            }
        }
        if notify { onSelect?(index) }
    }

    @objc private func didTapItem(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        UIView.transition(with: self, duration: 0.15, options: .transitionCrossDissolve) {
            self.setSelectedIndex(sender.tag)
        }
    }
}

/// v5 circular accent FAB (58×58) with lime glow; near-black plus icon.
final class SublyFloatingActionButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "plus")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        config.baseBackgroundColor = DesignSystem.Colors.accent
        config.baseForegroundColor = DesignSystem.Colors.accentOnFill
        config.cornerStyle = .capsule
        configuration = config

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 58),
            heightAnchor.constraint(equalToConstant: 58)
        ])

        layer.shadowColor = DesignSystem.Colors.accent.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 12)

        accessibilityLabel = Strings.Dashboard.addAccessibility

        configurationUpdateHandler = { button in
            let pressed = button.isHighlighted
            button.transform = pressed ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity
            button.layer.shadowOpacity = pressed ? 0.2 : 0.35
        }
    }
}
