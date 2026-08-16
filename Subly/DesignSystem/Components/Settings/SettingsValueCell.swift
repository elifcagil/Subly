import UIKit

final class SettingsValueCell: UITableViewCell {

    static let reuseIdentifier = "SettingsValueCell"

    // MARK: - Outlets

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var detailLabel: UILabel!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        isAccessibilityElement = true
    }

    // MARK: - Configuration

    func configure(title: String, detail: String) {
        titleLabel.text = title
        detailLabel.text = detail
        accessibilityLabel = "\(title), \(detail)"
    }
}
