import UIKit

final class SublyEmptyStateView: UIView {

    struct ViewModel {
        let title: String
        let message: String
        let systemIcon: String?
    }

    // MARK: - Outlets

    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!

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
        backgroundColor = .clear
        isAccessibilityElement = true
    }

    // MARK: - Configuration

    func configure(with viewModel: ViewModel) {
        titleLabel.text = viewModel.title
        messageLabel.text = viewModel.message
        if let name = viewModel.systemIcon {
            iconView.image = UIImage(systemName: name)
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }
        accessibilityLabel = "\(viewModel.title). \(viewModel.message)"
    }
}
