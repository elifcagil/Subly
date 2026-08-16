import UIKit

/// v5 service tile: a solid brand-colored rounded square with a paired
/// foreground initial (or an SF Symbol). Sizes: 40 (list), 44 (catalog),
/// 72 (detail hero); radius scales proportionally (12 at 40pt).
final class SublyAvatarView: UIView {

    struct ViewModel {
        enum Content: Equatable {
            case initial(String)
            case icon(String)
        }
        let content: Content
        let background: UIColor
        let foreground: UIColor

        init(initial: String, background: UIColor, foreground: UIColor) {
            self.content = .initial(initial)
            self.background = background
            self.foreground = foreground
        }

        init(icon: String, background: UIColor, foreground: UIColor) {
            self.content = .icon(icon)
            self.background = background
            self.foreground = foreground
        }

        // Back-compat: monogram + single color (foreground on 13% tint).
        init(monogram: String, color: UIColor) {
            self.content = .initial(monogram)
            self.background = color
            self.foreground = color
        }

        init(systemIcon: String, tint: UIColor) {
            self.content = .icon(systemIcon)
            self.background = tint.withAlphaComponent(0.14)
            self.foreground = tint
        }
    }

    static let standardSize: CGFloat = 40

    private let initialLabel = UILabel()
    private let iconView = UIImageView()
    private var side: CGFloat = SublyAvatarView.standardSize
    private var sizeConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        layer.cornerCurve = .continuous
        isAccessibilityElement = false

        initialLabel.translatesAutoresizingMaskIntoConstraints = false
        initialLabel.textAlignment = .center
        initialLabel.adjustsFontForContentSizeCategory = true
        initialLabel.adjustsFontSizeToFitWidth = true
        initialLabel.minimumScaleFactor = 0.6
        addSubview(initialLabel)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
        addSubview(iconView)

        NSLayoutConstraint.activate([
            initialLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            initialLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            initialLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
            iconView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5)
        ])
        setSize(side)
    }

    func configure(with viewModel: ViewModel) {
        backgroundColor = viewModel.background
        switch viewModel.content {
        case .initial(let text):
            initialLabel.isHidden = false
            iconView.isHidden = true
            initialLabel.text = text
            initialLabel.textColor = viewModel.foreground
            initialLabel.font = tileFont(forSide: side)
        case .icon(let symbol):
            initialLabel.isHidden = true
            iconView.isHidden = false
            iconView.image = UIImage(systemName: symbol)
            iconView.tintColor = viewModel.foreground
        }
    }

    func setSize(_ size: CGFloat) {
        side = size
        NSLayoutConstraint.deactivate(sizeConstraints)
        sizeConstraints = [
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size)
        ]
        NSLayoutConstraint.activate(sizeConstraints)
        layer.cornerRadius = DesignSystem.Radius.tile(forSide: size)
        if !initialLabel.isHidden {
            initialLabel.font = tileFont(forSide: size)
        }
    }

    private func tileFont(forSide side: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: round(side * 0.42), weight: .bold)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
    }
}
