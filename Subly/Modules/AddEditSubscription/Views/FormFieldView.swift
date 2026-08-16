import UIKit

final class FormFieldView: UIView {

    // MARK: - Outlets

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var contentContainer: UIView!

    // MARK: - State

    private let fieldTitle: String

    var contentView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let view = contentView else { return }
            view.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(view)
            view.accessibilityLabel = view.accessibilityLabel ?? fieldTitle
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
            ])
        }
    }

    // MARK: - Init

    init(title: String) {
        self.fieldTitle = title
        super.init(frame: .zero)
        loadContentView()
        applyStyling()
        titleLabel.text = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported.")
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
        titleLabel.font = DesignSystem.Typography.footnote
        titleLabel.textColor = DesignSystem.Colors.textSecondary
        titleLabel.adjustsFontForContentSizeCategory = true
    }
}
