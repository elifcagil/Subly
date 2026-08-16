import UIKit

final class SectionHeaderView: UITableViewHeaderFooterView {

    static let reuseIdentifier = "SectionHeaderView"

    // MARK: - Outlets

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var countLabel: UILabel!

    // MARK: - Init

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
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
        contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func applyStyling() {
        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = .clear
        backgroundConfiguration = background
    }

    // MARK: - Configuration

    func configure(title: String, count: Int?) {
        titleLabel.text = title.uppercased()
        if let count {
            countLabel.text = "\(count)"
            countLabel.isHidden = false
        } else {
            countLabel.isHidden = true
        }
        accessibilityLabel = count.map { "\(title), \($0) items" } ?? title
    }
}
