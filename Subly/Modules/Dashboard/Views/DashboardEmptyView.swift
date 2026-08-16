import UIKit

/// v5 empty state (screen 12): three stacked skeleton pills (the last one
/// accent — echoing the logo), "Nothing tracked yet", subcopy, a primary
/// "Add a subscription" button and a "Try with sample data" text button.
final class DashboardEmptyView: UIView {

    var onAdd: (() -> Void)?
    var onSampleData: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        // Skeleton pills — widths step down; last pill is accent.
        let pillSpecs: [(width: CGFloat, color: UIColor)] = [
            (150, DesignSystem.Colors.chartDim),
            (110, DesignSystem.Colors.chartDim),
            (130, DesignSystem.Colors.accent)
        ]
        let pills = pillSpecs.map { spec -> UIView in
            let pill = UIView()
            pill.backgroundColor = spec.color
            pill.layer.cornerRadius = 7
            pill.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                pill.widthAnchor.constraint(equalToConstant: spec.width),
                pill.heightAnchor.constraint(equalToConstant: 14)
            ])
            return pill
        }
        let pillsStack = UIStackView(arrangedSubviews: pills)
        pillsStack.axis = .vertical
        pillsStack.alignment = .center
        pillsStack.spacing = 10
        pillsStack.isAccessibilityElement = false

        let titleLabel = UILabel()
        titleLabel.text = Strings.EmptyState.title
        titleLabel.font = DesignSystem.Typography.title
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        let messageLabel = UILabel()
        messageLabel.text = Strings.EmptyState.message
        messageLabel.font = DesignSystem.Typography.body
        messageLabel.textColor = DesignSystem.Colors.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.adjustsFontForContentSizeCategory = true

        let addButton = UIButton(type: .system)
        var addConfig = UIButton.Configuration.filled()
        addConfig.title = Strings.EmptyState.add
        addConfig.baseBackgroundColor = DesignSystem.Colors.accent
        addConfig.baseForegroundColor = DesignSystem.Colors.accentOnFill
        addConfig.background.cornerRadius = DesignSystem.Radius.button
        addConfig.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 28, bottom: 15, trailing: 28)
        addButton.configuration = addConfig
        addButton.titleLabel?.font = DesignSystem.Typography.rowTitle
        addButton.titleLabel?.adjustsFontForContentSizeCategory = true
        addButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)

        let sampleButton = UIButton(type: .system)
        var sampleConfig = UIButton.Configuration.plain()
        sampleConfig.title = Strings.EmptyState.sample
        sampleConfig.baseForegroundColor = DesignSystem.Colors.accentText
        sampleConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        sampleButton.configuration = sampleConfig
        sampleButton.titleLabel?.font = DesignSystem.Typography.body
        sampleButton.titleLabel?.adjustsFontForContentSizeCategory = true
        sampleButton.addTarget(self, action: #selector(didTapSample), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [pillsStack, titleLabel, messageLabel, addButton, sampleButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignSystem.Spacing.sm
        stack.setCustomSpacing(DesignSystem.Spacing.xl, after: pillsStack)
        stack.setCustomSpacing(DesignSystem.Spacing.xl, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func didTapAdd() {
        onAdd?()
    }

    @objc private func didTapSample() {
        onSampleData?()
    }
}
