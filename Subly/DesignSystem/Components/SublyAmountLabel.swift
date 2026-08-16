import UIKit

final class SublyAmountLabel: UILabel {

    enum Emphasis {
        case primary
        case secondary
        case display

        var font: UIFont {
            switch self {
            case .primary: return DesignSystem.Typography.amountCompact
            case .secondary: return DesignSystem.Typography.footnote
            case .display: return DesignSystem.Typography.amount
            }
        }

        var color: UIColor {
            switch self {
            case .primary, .display: return DesignSystem.Colors.textPrimary
            case .secondary: return DesignSystem.Colors.textSecondary
            }
        }
    }

    var emphasis: Emphasis = .primary {
        didSet { applyEmphasis() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        adjustsFontForContentSizeCategory = true
        numberOfLines = 1
        applyEmphasis()
    }

    private func applyEmphasis() {
        font = emphasis.font
        textColor = emphasis.color
    }

    /// Sets a monetary value with the decimal portion dimmed to `ink/tertiary`
    /// (v5 hero-amount treatment). Splits on the last "." or "," so it works
    /// regardless of which separator the currency formatter emitted.
    func setDimmedDecimals(_ text: String, font: UIFont? = nil) {
        let useFont = font ?? emphasis.font
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [.font: useFont, .foregroundColor: DesignSystem.Colors.textPrimary]
        )
        let separators = CharacterSet(charactersIn: ".,")
        if let range = text.rangeOfCharacter(from: separators, options: .backwards),
           // Only dim when digits follow (a real decimal part, not a grouping dot).
           text[range.upperBound...].allSatisfy(\.isNumber),
           !text[range.upperBound...].isEmpty {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            attributed.addAttribute(
                .foregroundColor,
                value: DesignSystem.Colors.textTertiary,
                range: NSRange(location: start, length: text.count - start)
            )
        }
        attributedText = attributed
    }
}
