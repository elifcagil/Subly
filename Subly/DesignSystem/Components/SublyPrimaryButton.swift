import UIKit

final class SublyPrimaryButton: UIButton {

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
        config.cornerStyle = .large
        config.baseBackgroundColor = DesignSystem.Colors.accent
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(
            top: DesignSystem.Spacing.md,
            leading: DesignSystem.Spacing.xl,
            bottom: DesignSystem.Spacing.md,
            trailing: DesignSystem.Spacing.xl
        )
        configuration = config
        titleLabel?.font = DesignSystem.Typography.headline
        titleLabel?.adjustsFontForContentSizeCategory = true
        accessibilityTraits = .button
    }

    func setTitle(_ title: String) {
        var config = configuration ?? .filled()
        config.title = title
        configuration = config
        accessibilityLabel = title
    }
}
