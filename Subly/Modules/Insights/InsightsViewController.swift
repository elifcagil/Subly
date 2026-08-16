import UIKit

final class InsightsViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: InsightsViewModel

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var emptyStateView: SublyEmptyStateView!

    private let currencyChipScrollView = UIScrollView()
    private let currencyChipStack = UIStackView()
    private let monthlyCard = SublyStatCard()
    private let yearlyCard = SublyStatCard()
    private let largestCard = SublyStatCard()
    private let breakdownChart = CategoryBreakdownChartView()
    private let breakdownTitle = UILabel()
    private let breakdownEmpty = UILabel()
    private let projectionTitle = UILabel()
    private let projectionStack = UIStackView()

    private let pressureTitle = UILabel()
    private let pressureScrollView = UIScrollView()
    private let pressureStack = UIStackView()

    // MARK: - Init

    init(viewModel: InsightsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:).")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.Insights.title
        view.backgroundColor = DesignSystem.Colors.background
        configureHierarchy()
        configureBindings()
        viewModel.start()
    }

    // MARK: - Configuration

    private func configureHierarchy() {
        scrollView.alwaysBounceVertical = true
        contentStack.spacing = DesignSystem.Spacing.lg
        configureCurrencyChips()
        configureStatGrid()
        configurePressureSection()
        configureBreakdownSection()
        configureProjectionSection()
    }

    /// Phase 9 §9.8 — 8-week horizontal Pressure strip. Each tile shows a
    /// week label, a total amount, and a tone-coloured chip. Per-currency
    /// (uses whatever the currency chip strip resolves to).
    private func configurePressureSection() {
        pressureTitle.text = Strings.FinancialLoad.title
        pressureTitle.font = DesignSystem.Typography.title
        pressureTitle.textColor = DesignSystem.Colors.textPrimary
        pressureTitle.adjustsFontForContentSizeCategory = true

        pressureScrollView.showsHorizontalScrollIndicator = false
        pressureScrollView.alwaysBounceHorizontal = true
        pressureScrollView.backgroundColor = .clear
        pressureScrollView.translatesAutoresizingMaskIntoConstraints = false

        pressureStack.axis = .horizontal
        pressureStack.alignment = .top
        pressureStack.spacing = DesignSystem.Spacing.sm
        pressureStack.translatesAutoresizingMaskIntoConstraints = false
        pressureScrollView.addSubview(pressureStack)
        NSLayoutConstraint.activate([
            pressureStack.topAnchor.constraint(equalTo: pressureScrollView.topAnchor),
            pressureStack.bottomAnchor.constraint(equalTo: pressureScrollView.bottomAnchor),
            pressureStack.leadingAnchor.constraint(equalTo: pressureScrollView.leadingAnchor),
            pressureStack.trailingAnchor.constraint(equalTo: pressureScrollView.trailingAnchor),
            pressureStack.heightAnchor.constraint(equalTo: pressureScrollView.heightAnchor)
        ])
        pressureScrollView.heightAnchor.constraint(equalToConstant: 96).isActive = true
        pressureScrollView.isHidden = true

        contentStack.addArrangedSubview(pressureTitle)
        contentStack.addArrangedSubview(pressureScrollView)
    }

    private func applyPressureTiles(_ tiles: [InsightsViewModel.PressureTile]) {
        pressureStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let hide = tiles.isEmpty
        pressureScrollView.isHidden = hide
        pressureTitle.isHidden = hide
        guard !hide else { return }
        for tile in tiles {
            pressureStack.addArrangedSubview(makePressureTileView(tile))
        }
    }

    private func makePressureTileView(_ tile: InsightsViewModel.PressureTile) -> UIView {
        let card = SublyCardView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let weekLabel = UILabel()
        weekLabel.text = tile.weekLabel
        weekLabel.font = DesignSystem.Typography.footnote
        weekLabel.textColor = DesignSystem.Colors.textSecondary
        weekLabel.adjustsFontForContentSizeCategory = true

        let amountLabel = UILabel()
        amountLabel.text = tile.amountText
        amountLabel.font = DesignSystem.Typography.subhead
        amountLabel.textColor = DesignSystem.Colors.textPrimary
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.numberOfLines = 1
        amountLabel.lineBreakMode = .byTruncatingTail

        let toneChip = SublyChip()
        toneChip.configure(with: .init(
            text: Strings.FinancialLoad.toneLabel(tile.tone),
            systemIcon: nil,
            tone: pressureChipTone(for: tile.tone)
        ))

        let stack = UIStackView(arrangedSubviews: [weekLabel, amountLabel, toneChip])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = DesignSystem.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignSystem.Spacing.md),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignSystem.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignSystem.Spacing.md),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignSystem.Spacing.md),
            card.widthAnchor.constraint(equalToConstant: 132)
        ])
        card.isAccessibilityElement = true
        card.accessibilityLabel = "\(tile.weekLabel), \(tile.amountText), \(Strings.FinancialLoad.toneLabel(tile.tone))"
        return card
    }

    /// Tone → chip mapping. Per §9.12, `.peak` does **not** map to `.danger`.
    private func pressureChipTone(for tone: FinancialLoadWindow.Tone) -> SublyChip.Tone {
        switch tone {
        case .light: return .neutral
        case .moderate: return .accent
        case .heavy, .peak: return .warning
        }
    }

    private func configureCurrencyChips() {
        currencyChipScrollView.showsHorizontalScrollIndicator = false
        currencyChipScrollView.showsVerticalScrollIndicator = false
        currencyChipScrollView.backgroundColor = .clear
        currencyChipScrollView.translatesAutoresizingMaskIntoConstraints = false

        currencyChipStack.axis = .horizontal
        currencyChipStack.alignment = .center
        currencyChipStack.spacing = DesignSystem.Spacing.sm
        currencyChipStack.translatesAutoresizingMaskIntoConstraints = false

        currencyChipScrollView.addSubview(currencyChipStack)
        NSLayoutConstraint.activate([
            currencyChipStack.topAnchor.constraint(equalTo: currencyChipScrollView.topAnchor),
            currencyChipStack.bottomAnchor.constraint(equalTo: currencyChipScrollView.bottomAnchor),
            currencyChipStack.leadingAnchor.constraint(equalTo: currencyChipScrollView.leadingAnchor),
            currencyChipStack.trailingAnchor.constraint(equalTo: currencyChipScrollView.trailingAnchor),
            currencyChipStack.heightAnchor.constraint(equalTo: currencyChipScrollView.heightAnchor)
        ])
        // 40pt — enough for caption font + diacritics (Türkçe Ü/Ş/Ç) without clipping.
        currencyChipScrollView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        currencyChipScrollView.isHidden = true
        contentStack.addArrangedSubview(currencyChipScrollView)
    }

    private func applyCurrencyChips(_ chips: [InsightsViewModel.CurrencyChip]) {
        currencyChipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // Hide the strip when there is only one currency — no choice to offer.
        currencyChipScrollView.isHidden = chips.count <= 1
        for chip in chips {
            let button = InsightsChipButton(title: chip.title, isSelected: chip.isSelected)
            button.onTap = { [weak self] in
                self?.viewModel.selectCurrency(chip.code)
            }
            currencyChipStack.addArrangedSubview(button)
        }
    }

    private func configureStatGrid() {
        let topRow = UIStackView(arrangedSubviews: [monthlyCard, yearlyCard])
        topRow.axis = .horizontal
        topRow.spacing = DesignSystem.Spacing.md
        topRow.distribution = .fillEqually

        contentStack.addArrangedSubview(topRow)
        contentStack.addArrangedSubview(largestCard)
    }

    private func configureBreakdownSection() {
        breakdownTitle.text = Strings.Insights.whereItGoes
        breakdownTitle.font = DesignSystem.Typography.title
        breakdownTitle.textColor = DesignSystem.Colors.textPrimary
        breakdownTitle.adjustsFontForContentSizeCategory = true

        breakdownEmpty.text = Strings.Insights.noBreakdown
        breakdownEmpty.font = DesignSystem.Typography.footnote
        breakdownEmpty.textColor = DesignSystem.Colors.textSecondary
        breakdownEmpty.adjustsFontForContentSizeCategory = true
        breakdownEmpty.numberOfLines = 0
        breakdownEmpty.isHidden = true

        let breakdownCard = SublyCardView()
        breakdownCard.translatesAutoresizingMaskIntoConstraints = false
        breakdownChart.translatesAutoresizingMaskIntoConstraints = false
        breakdownCard.addSubview(breakdownChart)
        breakdownCard.addSubview(breakdownEmpty)

        breakdownEmpty.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            breakdownChart.topAnchor.constraint(equalTo: breakdownCard.topAnchor, constant: DesignSystem.Spacing.lg),
            breakdownChart.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: DesignSystem.Spacing.lg),
            breakdownChart.trailingAnchor.constraint(equalTo: breakdownCard.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            breakdownChart.bottomAnchor.constraint(equalTo: breakdownCard.bottomAnchor, constant: -DesignSystem.Spacing.lg),

            breakdownEmpty.topAnchor.constraint(equalTo: breakdownCard.topAnchor, constant: DesignSystem.Spacing.lg),
            breakdownEmpty.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: DesignSystem.Spacing.lg),
            breakdownEmpty.trailingAnchor.constraint(equalTo: breakdownCard.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            breakdownEmpty.bottomAnchor.constraint(equalTo: breakdownCard.bottomAnchor, constant: -DesignSystem.Spacing.lg)
        ])

        contentStack.addArrangedSubview(breakdownTitle)
        contentStack.addArrangedSubview(breakdownCard)
    }

    private func configureProjectionSection() {
        projectionTitle.text = Strings.Insights.nextFourWeeks
        projectionTitle.font = DesignSystem.Typography.title
        projectionTitle.textColor = DesignSystem.Colors.textPrimary
        projectionTitle.adjustsFontForContentSizeCategory = true

        projectionStack.axis = .vertical
        projectionStack.spacing = DesignSystem.Spacing.sm

        let card = SublyCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        projectionStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(projectionStack)
        NSLayoutConstraint.activate([
            projectionStack.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignSystem.Spacing.lg),
            projectionStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignSystem.Spacing.lg),
            projectionStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            projectionStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignSystem.Spacing.lg)
        ])

        contentStack.addArrangedSubview(projectionTitle)
        contentStack.addArrangedSubview(card)
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    // MARK: - Rendering

    private func render(_ state: ViewState<InsightsViewModel.Snapshot>) {
        switch state {
        case .idle, .loading:
            scrollView.isHidden = false
            emptyStateView.isHidden = true
        case .loaded(let snapshot):
            scrollView.isHidden = false
            emptyStateView.isHidden = true
            apply(snapshot)
        case .empty:
            scrollView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(with: .init(
                title: Strings.Insights.emptyTitle,
                message: Strings.Insights.emptyMessage,
                systemIcon: "chart.pie"
            ))
        case .failed(let message):
            scrollView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(with: .init(
                title: Strings.Common.somethingWentWrong,
                message: message,
                systemIcon: "exclamationmark.triangle"
            ))
        }
    }

    private func apply(_ snapshot: InsightsViewModel.Snapshot) {
        applyCurrencyChips(snapshot.currencyChips)
        applyPressureTiles(snapshot.pressureTiles)
        monthlyCard.configure(with: .init(
            caption: Strings.Insights.monthlyCaption,
            value: snapshot.monthlyTotal,
            footnote: Strings.Dashboard.activeSubscriptions(snapshot.activeCount)
        ))
        yearlyCard.configure(with: .init(
            caption: Strings.Insights.yearlyCaption,
            value: snapshot.yearlyProjection,
            footnote: Strings.Insights.yearlyFootnote
        ))

        if let largest = snapshot.largestUpcoming {
            largestCard.isHidden = false
            largestCard.configure(with: .init(
                caption: Strings.Insights.biggestUpcoming,
                value: largest.amountText,
                footnote: "\(largest.name) · \(largest.dateText)"
            ))
        } else {
            largestCard.isHidden = true
        }

        if snapshot.breakdown.rows.isEmpty {
            breakdownChart.isHidden = true
            breakdownEmpty.isHidden = false
        } else {
            breakdownChart.isHidden = false
            breakdownEmpty.isHidden = true
            breakdownChart.configure(with: snapshot.breakdown)
        }

        renderProjection(snapshot.projection)
    }

    private func renderProjection(_ rows: [InsightsViewModel.ProjectionRow]) {
        projectionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !rows.isEmpty else {
            let empty = UILabel()
            empty.text = Strings.Insights.noRenewals
            empty.font = DesignSystem.Typography.footnote
            empty.textColor = DesignSystem.Colors.textSecondary
            empty.numberOfLines = 0
            empty.adjustsFontForContentSizeCategory = true
            projectionStack.addArrangedSubview(empty)
            return
        }
        for (index, row) in rows.enumerated() {
            projectionStack.addArrangedSubview(makeProjectionRow(row))
            if index < rows.count - 1 {
                projectionStack.addArrangedSubview(makeSeparator())
            }
        }
    }

    private func makeProjectionRow(_ row: InsightsViewModel.ProjectionRow) -> UIView {
        let week = UILabel()
        week.text = Strings.Insights.weekOf(row.weekLabel)
        week.font = DesignSystem.Typography.body
        week.textColor = DesignSystem.Colors.textPrimary
        week.adjustsFontForContentSizeCategory = true

        let detail = UILabel()
        detail.text = Strings.Insights.renewalsCount(row.count)
        detail.font = DesignSystem.Typography.footnote
        detail.textColor = DesignSystem.Colors.textSecondary
        detail.adjustsFontForContentSizeCategory = true

        let textStack = UIStackView(arrangedSubviews: [week, detail])
        textStack.axis = .vertical
        textStack.spacing = DesignSystem.Spacing.xs

        let amount = SublyAmountLabel()
        amount.emphasis = .primary
        amount.text = row.amountText
        amount.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [textStack, amount])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = DesignSystem.Spacing.md
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = "\(Strings.Insights.weekOf(row.weekLabel)), \(row.amountText), \(Strings.Insights.renewalsCount(row.count))"
        return stack
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = DesignSystem.Colors.separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }
}

// MARK: - Currency chip

/// Local pill-style chip for the Insights currency strip.
/// Mirrors `SubscriptionListViewController.ChipButton`; if a third callsite
/// appears, promote to a shared component in `DesignSystem/`.
private final class InsightsChipButton: UIControl {

    var onTap: (() -> Void)?

    private let label = UILabel()

    init(title: String, isSelected: Bool) {
        super.init(frame: .zero)
        configure(title: title, isSelected: isSelected)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure(title: String, isSelected: Bool) {
        layer.cornerRadius = DesignSystem.Radius.pill
        layer.cornerCurve = .continuous

        let foreground: UIColor = isSelected ? .white : DesignSystem.Colors.textSecondary
        let background: UIColor = isSelected
            ? DesignSystem.Colors.accent
            : DesignSystem.Colors.surfaceElevated
        backgroundColor = background

        label.text = title
        label.textColor = foreground
        label.font = DesignSystem.Typography.caption
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: DesignSystem.Spacing.xs),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignSystem.Spacing.xs),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignSystem.Spacing.md),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSystem.Spacing.md)
        ])

        accessibilityLabel = title
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    @objc private func handleTap() {
        onTap?()
    }
}
