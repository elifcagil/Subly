import UIKit

final class UpcomingRenewalCell: UITableViewCell {

    static let reuseIdentifier = "UpcomingRenewalCell"

    // MARK: - Outlets

    @IBOutlet private weak var avatarView: SublyAvatarView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var amountLabel: SublyAmountLabel!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        isAccessibilityElement = true
        accessibilityTraits = .button
        amountLabel.emphasis = .primary
    }

    // MARK: - Configuration

    func configure(with row: DashboardViewModel.UpcomingRow) {
        nameLabel.text = row.name
        dateLabel.text = row.dateText
        amountLabel.text = row.amountText
        let brand = SublyBrandAppearance.appearance(forName: row.name, categoryName: nil)
        avatarView.configure(with: .init(initial: brand.initial, background: brand.background, foreground: brand.foreground))
        accessibilityLabel = "\(row.name), \(row.amountText), renews \(row.dateText)"
        accessibilityHint = "Double tap to view details."
    }
}
