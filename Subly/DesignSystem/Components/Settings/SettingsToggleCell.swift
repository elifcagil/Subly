import UIKit

final class SettingsToggleCell: UITableViewCell {

    static let reuseIdentifier = "SettingsToggleCell"

    // MARK: - Outlets

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var toggle: UISwitch!

    // MARK: - State

    private var onToggle: ((Bool) -> Void)?

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        isAccessibilityElement = false
        // v5: accent-tinted switch (lime fill; thumb contrast handled by system).
        toggle.onTintColor = DesignSystem.Colors.accent
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggle = nil
    }

    // MARK: - Configuration

    func configure(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        titleLabel.text = title
        if toggle.isOn != isOn {
            toggle.setOn(isOn, animated: false)
        }
        onToggle = onChange
        accessibilityLabel = title
    }

    // MARK: - Actions

    @objc private func toggleChanged() {
        onToggle?(toggle.isOn)
    }
}
