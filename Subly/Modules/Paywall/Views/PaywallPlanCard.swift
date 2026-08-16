import UIKit

final class PaywallPlanCard: UIControl {

    struct ViewModel {
        let productID: String
        let planTitle: String
        let priceText: String
        let perMonthText: String?
        let highlightAsBest: Bool
    }

    private(set) var productID: String = ""

    // MARK: - Outlets

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var bestValueChip: SublyChip!
    @IBOutlet private weak var priceLabel: SublyAmountLabel!
    @IBOutlet private weak var perMonthLabel: UILabel!
    @IBOutlet private weak var radioImageView: UIImageView!

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
        content.isUserInteractionEnabled = false
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
        backgroundColor = DesignSystem.Colors.surface
        layer.cornerRadius = DesignSystem.Radius.lg
        layer.cornerCurve = .continuous
        layer.borderWidth = 2
        layer.borderColor = UIColor.clear.cgColor

        let shadow = DesignSystem.Shadow.low
        layer.shadowColor = shadow.color.cgColor
        layer.shadowOpacity = shadow.opacity
        layer.shadowRadius = shadow.radius
        layer.shadowOffset = shadow.offset

        priceLabel.emphasis = .primary
    }

    // MARK: - State

    override var isSelected: Bool {
        didSet { applySelectionState() }
    }

    // MARK: - Configuration

    func configure(with viewModel: ViewModel, isSelected: Bool) {
        productID = viewModel.productID
        titleLabel.text = viewModel.planTitle
        priceLabel.text = viewModel.priceText
        if let perMonth = viewModel.perMonthText {
            perMonthLabel.text = perMonth
            perMonthLabel.isHidden = false
        } else {
            perMonthLabel.isHidden = true
        }
        if viewModel.highlightAsBest {
            bestValueChip.isHidden = false
            bestValueChip.configure(with: .init(
                text: Strings.Paywall.bestValue,
                systemIcon: nil,
                tone: .accent
            ))
        } else {
            bestValueChip.isHidden = true
        }
        self.isSelected = isSelected

        let accessibility = [viewModel.planTitle, viewModel.priceText, viewModel.perMonthText]
            .compactMap { $0 }
            .joined(separator: ", ")
        accessibilityLabel = accessibility
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    private func applySelectionState() {
        let borderColor: UIColor = isSelected ? DesignSystem.Colors.accent : .clear
        layer.borderColor = borderColor.cgColor
        radioImageView.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        radioImageView.tintColor = isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary
    }
}
