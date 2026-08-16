import UIKit

final class SublyStatCard: UIView {

    struct ViewModel {
        let caption: String
        let value: String
        let footnote: String?
    }

    // MARK: - Outlets

    @IBOutlet private weak var card: SublyCardView!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var valueLabel: SublyAmountLabel!
    @IBOutlet private weak var footnoteLabel: UILabel!

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
        isAccessibilityElement = true
        valueLabel.emphasis = .display
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
    }

    // MARK: - Configuration

    func configure(with viewModel: ViewModel) {
        captionLabel.text = viewModel.caption
        valueLabel.text = viewModel.value
        if let footnote = viewModel.footnote {
            footnoteLabel.text = footnote
            footnoteLabel.isHidden = false
        } else {
            footnoteLabel.isHidden = true
        }
        accessibilityLabel = [viewModel.caption, viewModel.value, viewModel.footnote]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
