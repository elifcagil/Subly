import UIKit

/// v5 subscription row (screen 03): 40pt brand tile · name + "Category · date"
/// meta · price (tabular) with a lowercase cycle sub-label.
final class SubscriptionCell: UITableViewCell {

    static let reuseIdentifier = "SubscriptionCell"

    // MARK: - Outlets

    @IBOutlet private weak var avatarView: SublyAvatarView!
    @IBOutlet private weak var primaryLabel: UILabel!
    @IBOutlet private weak var secondaryLabel: UILabel!
    @IBOutlet private weak var amountLabel: SublyAmountLabel!
    @IBOutlet private weak var cycleLabel: UILabel!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        isAccessibilityElement = true
        accessibilityTraits = .button
        backgroundColor = DesignSystem.Colors.surface

        primaryLabel.font = DesignSystem.Typography.rowTitle
        primaryLabel.textColor = DesignSystem.Colors.textPrimary
        secondaryLabel.font = DesignSystem.Typography.footnote
        secondaryLabel.textColor = DesignSystem.Colors.textSecondary
        amountLabel.emphasis = .primary
        cycleLabel.font = DesignSystem.Typography.caption
        cycleLabel.textColor = DesignSystem.Colors.textTertiary
    }

    // MARK: - Configuration

    func configure(with row: SubscriptionListViewModel.Row) {
        primaryLabel.text = row.primaryText
        secondaryLabel.text = row.secondaryText
        amountLabel.text = row.amountText
        cycleLabel.text = row.cycleText

        let brand = SublyBrandAppearance.appearance(forName: row.primaryText, categoryName: row.categoryName)
        avatarView.configure(with: .init(initial: brand.initial, background: brand.background, foreground: brand.foreground))

        accessibilityLabel = "\(row.primaryText), \(row.amountText) \(row.cycleText). \(row.secondaryText)"
        accessibilityHint = Strings.SubscriptionList.rowHint
    }
}
