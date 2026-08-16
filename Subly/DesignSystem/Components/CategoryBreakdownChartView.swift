import UIKit

final class CategoryBreakdownChartView: UIView {

    struct ViewModel: Hashable {
        let rows: [Row]

        struct Row: Hashable {
            let title: String
            let valueText: String
            let share: Double
            let systemIcon: String
        }
    }

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureHierarchy()
    }

    func configure(with viewModel: ViewModel) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for row in viewModel.rows {
            stack.addArrangedSubview(makeRow(row))
        }
    }

    private func configureHierarchy() {
        stack.axis = .vertical
        stack.spacing = DesignSystem.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func makeRow(_ row: ViewModel.Row) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: row.systemIcon))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.tintColor = DesignSystem.Colors.textSecondary
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: DesignSystem.Typography.subhead)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = UILabel()
        titleLabel.text = row.title
        titleLabel.font = DesignSystem.Typography.subhead
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true

        let valueLabel = UILabel()
        valueLabel.text = row.valueText
        valueLabel.font = DesignSystem.Typography.amountCompact
        valueLabel.textColor = DesignSystem.Colors.textPrimary
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [icon, titleLabel, valueLabel])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = DesignSystem.Spacing.sm

        let bar = BarView()
        bar.share = max(0, min(row.share, 1))
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let container = UIStackView(arrangedSubviews: [header, bar])
        container.axis = .vertical
        container.spacing = DesignSystem.Spacing.xs

        let sharePct = Int((row.share * 100).rounded())
        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(row.title), \(row.valueText), \(sharePct) percent of monthly spend"

        return container
    }
}

private final class BarView: UIView {

    private let track = UIView()
    private let fill = UIView()
    private var fillWidth: NSLayoutConstraint?

    var share: Double = 0 {
        didSet { updateFill() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        track.backgroundColor = DesignSystem.Colors.separator
        track.layer.cornerRadius = 3
        track.layer.cornerCurve = .continuous
        track.translatesAutoresizingMaskIntoConstraints = false

        fill.backgroundColor = DesignSystem.Colors.accent
        fill.layer.cornerRadius = 3
        fill.layer.cornerCurve = .continuous
        fill.translatesAutoresizingMaskIntoConstraints = false

        addSubview(track)
        track.addSubview(fill)

        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),

            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor)
        ])

        let width = fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: 0)
        width.isActive = true
        fillWidth = width
    }

    private func updateFill() {
        guard let fillWidth else { return }
        fillWidth.isActive = false
        let next = fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: CGFloat(share))
        next.isActive = true
        self.fillWidth = next
    }
}
