import UIKit

final class SublyChip: UIView {

    struct ViewModel {
        let text: String
        let systemIcon: String?
        let tone: Tone
    }

    enum Tone {
        case neutral
        case accent
        case positive
        case warning
        case danger

        var foreground: UIColor {
            switch self {
            case .neutral: return DesignSystem.Colors.textSecondary
            case .accent: return DesignSystem.Colors.accentDeep
            case .positive: return DesignSystem.Colors.positive
            case .warning: return DesignSystem.Colors.warning
            case .danger: return DesignSystem.Colors.danger
            }
        }

        var background: UIColor {
            switch self {
            case .neutral: return DesignSystem.Colors.textSecondary.withAlphaComponent(0.10)
            case .accent: return DesignSystem.Colors.accentTint
            case .positive: return DesignSystem.Colors.positiveTint
            case .warning: return DesignSystem.Colors.warning.withAlphaComponent(0.14)
            case .danger: return DesignSystem.Colors.dangerTint
            }
        }
    }

    // MARK: - Outlets

    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var textLabel: UILabel!

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        loadContentView()
        applyStyling()
    }

    private func loadContentView() {
        let bundle = Bundle(for: Self.self)
        let nib = UINib(nibName: String(describing: Self.self), bundle: bundle)
        guard let content = nib.instantiate(withOwner: self).first as? UIView else { return }
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func applyStyling() {
        layer.cornerRadius = DesignSystem.Radius.pill
        layer.cornerCurve = .continuous
        isAccessibilityElement = true

        textLabel.font = DesignSystem.Typography.caption
        textLabel.adjustsFontForContentSizeCategory = true

        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            font: DesignSystem.Typography.caption
        )
    }

    // MARK: - Configuration

    func configure(with viewModel: ViewModel) {
        textLabel.text = viewModel.text
        textLabel.textColor = viewModel.tone.foreground
        iconView.tintColor = viewModel.tone.foreground
        if let icon = viewModel.systemIcon {
            iconView.image = UIImage(systemName: icon)
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }
        backgroundColor = viewModel.tone.background
        accessibilityLabel = viewModel.text
    }
}
