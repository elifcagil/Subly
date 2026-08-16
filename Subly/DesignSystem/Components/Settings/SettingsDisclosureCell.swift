import UIKit

final class SettingsDisclosureCell: UITableViewCell {

    static let reuseIdentifier = "SettingsDisclosureCell"

    enum Accessory {
        case detail(String)
        case chip(SublyChip.ViewModel)
        case none
    }

    // MARK: - Outlets

    @IBOutlet private weak var stack: UIStackView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var detailLabel: UILabel!
    @IBOutlet private weak var chip: SublyChip!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        accessibilityTraits = .button
        isAccessibilityElement = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        detailLabel.isHidden = false
        chip.isHidden = true
    }

    // MARK: - Configuration

    func configure(title: String, accessory: Accessory) {
        titleLabel.text = title

        switch accessory {
        case .detail(let value):
            detailLabel.text = value
            detailLabel.isHidden = false
            chip.isHidden = true
            accessibilityLabel = "\(title), \(value)"
        case .chip(let viewModel):
            chip.configure(with: viewModel)
            chip.isHidden = false
            detailLabel.isHidden = true
            accessibilityLabel = "\(title), \(viewModel.text)"
        case .none:
            detailLabel.isHidden = true
            chip.isHidden = true
            accessibilityLabel = title
        }
    }
}
