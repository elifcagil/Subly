import UIKit

/// v5 Dashboard (screen 02): date row + avatar, hero amount with 6-month mini
/// chart, trend line, "Next 7 days" card, "By category" stacked bar. The
/// floating tab bar + FAB live in `TabBarCoordinator`.
final class DashboardViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: DashboardViewModel
    private let haptics: HapticsService

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var emptyStateView: SublyEmptyStateView!

    /// v5 empty state (screen 12) — skeleton pills + CTA + sample-data button.
    private let emptyView = DashboardEmptyView()

    // Header
    private let dateLabel = UILabel()
    private let titleLabel = UILabel()
    private let avatarButton = UIButton(type: .system)

    // Hero
    private let thisMonthLabel = UILabel()
    /// Currency selector (roadmap §8.6 "Honest aggregation" — currencies are
    /// never converted into one number; the whole hero rescopes per chip).
    private let currencyChipScroll = UIScrollView()
    private let currencyChipStack = UIStackView()
    private let heroAmountLabel = SublyAmountLabel()
    private let miniChart = SublyBarChart()
    private let trendLabel = UILabel()

    // Next 7 days
    private let upcomingCard = SublyCardView()
    private let upcomingHeaderLabel = UILabel()
    private let upcomingStack = UIStackView()

    // By category
    private let categoryCard = SublyCardView()
    private let categoryHeaderLabel = UILabel()
    private let categoryBar = SublyCategoryBar()
    private let legendStack = UIStackView()

    // MARK: - Init

    init(viewModel: DashboardViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:haptics:).")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignSystem.Colors.background
        configureHierarchy()
        configureBindings()
        viewModel.start()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // v5 dashboard draws its own header; restore the bar for pushes.
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Configuration

    private func configureHierarchy() {
        scrollView.alwaysBounceVertical = true
        contentStack.spacing = DesignSystem.Spacing.section
        configureHeader()
        configureHero()
        configureUpcomingCard()
        configureCategoryCard()

        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        emptyView.onAdd = { [weak self] in
            self?.haptics.play(.lightImpact)
            self?.viewModel.didTapAdd()
        }
        emptyView.onSampleData = { [weak self] in
            self?.haptics.play(.selection)
            self?.viewModel.didTapSampleData()
        }
        view.addSubview(emptyView)
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            emptyView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func configureHeader() {
        dateLabel.font = DesignSystem.Typography.caption
        dateLabel.textColor = DesignSystem.Colors.textTertiary
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.text = Self.headerDateFormatter.string(from: Date()).uppercased()

        titleLabel.font = DesignSystem.Typography.largeTitle
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.text = Strings.Dashboard.title

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = DesignSystem.Colors.avatarBackground
        config.baseForegroundColor = DesignSystem.Colors.textSecondary
        config.image = UIImage(systemName: "gearshape.fill")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        config.cornerStyle = .capsule
        avatarButton.configuration = config
        avatarButton.accessibilityLabel = Strings.Settings.title
        avatarButton.addTarget(self, action: #selector(didTapAvatar), for: .touchUpInside)
        NSLayoutConstraint.activate([
            avatarButton.widthAnchor.constraint(equalToConstant: 34),
            avatarButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        let titleColumn = UIStackView(arrangedSubviews: [dateLabel, titleLabel])
        titleColumn.axis = .vertical
        titleColumn.spacing = 2

        let header = UIStackView(arrangedSubviews: [titleColumn, UIView(), avatarButton])
        header.axis = .horizontal
        header.alignment = .center
        contentStack.addArrangedSubview(header)
    }

    private func configureHero() {
        thisMonthLabel.font = DesignSystem.Typography.sectionHeader
        thisMonthLabel.textColor = DesignSystem.Colors.textSecondary
        thisMonthLabel.adjustsFontForContentSizeCategory = true
        thisMonthLabel.text = Strings.Dashboard.thisMonth

        heroAmountLabel.emphasis = .display
        heroAmountLabel.adjustsFontSizeToFitWidth = true
        heroAmountLabel.minimumScaleFactor = 0.5

        miniChart.translatesAutoresizingMaskIntoConstraints = false
        miniChart.heightAnchor.constraint(equalToConstant: 64).isActive = true
        miniChart.setContentHuggingPriority(.required, for: .horizontal)

        currencyChipStack.axis = .horizontal
        currencyChipStack.spacing = 8
        currencyChipStack.translatesAutoresizingMaskIntoConstraints = false
        currencyChipScroll.showsHorizontalScrollIndicator = false
        currencyChipScroll.clipsToBounds = false
        currencyChipScroll.addSubview(currencyChipStack)
        currencyChipScroll.isHidden = true
        NSLayoutConstraint.activate([
            currencyChipScroll.heightAnchor.constraint(equalToConstant: 32),
            currencyChipStack.topAnchor.constraint(equalTo: currencyChipScroll.contentLayoutGuide.topAnchor),
            currencyChipStack.bottomAnchor.constraint(equalTo: currencyChipScroll.contentLayoutGuide.bottomAnchor),
            currencyChipStack.leadingAnchor.constraint(equalTo: currencyChipScroll.contentLayoutGuide.leadingAnchor),
            currencyChipStack.trailingAnchor.constraint(equalTo: currencyChipScroll.contentLayoutGuide.trailingAnchor),
            currencyChipStack.heightAnchor.constraint(equalTo: currencyChipScroll.frameLayoutGuide.heightAnchor)
        ])

        let amountColumn = UIStackView(arrangedSubviews: [thisMonthLabel, currencyChipScroll, heroAmountLabel])
        amountColumn.axis = .vertical
        amountColumn.spacing = 4
        amountColumn.setCustomSpacing(10, after: thisMonthLabel)
        amountColumn.setCustomSpacing(10, after: currencyChipScroll)

        let heroRow = UIStackView(arrangedSubviews: [amountColumn, UIView(), miniChart])
        heroRow.axis = .horizontal
        heroRow.alignment = .bottom

        trendLabel.font = DesignSystem.Typography.footnote
        trendLabel.textColor = DesignSystem.Colors.textSecondary
        trendLabel.adjustsFontForContentSizeCategory = true
        trendLabel.numberOfLines = 0

        let hero = UIStackView(arrangedSubviews: [heroRow, trendLabel])
        hero.axis = .vertical
        hero.spacing = DesignSystem.Spacing.sm
        contentStack.addArrangedSubview(hero)
        contentStack.setCustomSpacing(DesignSystem.Spacing.xl, after: hero)
    }

    private func configureUpcomingCard() {
        upcomingHeaderLabel.font = DesignSystem.Typography.sectionHeader
        upcomingHeaderLabel.textColor = DesignSystem.Colors.textSecondary
        upcomingHeaderLabel.adjustsFontForContentSizeCategory = true
        upcomingHeaderLabel.text = Strings.Dashboard.nextSevenDays

        upcomingStack.axis = .vertical
        upcomingStack.spacing = 0

        let column = UIStackView(arrangedSubviews: [upcomingHeaderLabel, upcomingStack])
        column.axis = .vertical
        column.spacing = DesignSystem.Spacing.sm
        column.translatesAutoresizingMaskIntoConstraints = false

        upcomingCard.translatesAutoresizingMaskIntoConstraints = false
        upcomingCard.addSubview(column)
        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: upcomingCard.topAnchor, constant: pad),
            column.leadingAnchor.constraint(equalTo: upcomingCard.leadingAnchor, constant: pad),
            column.trailingAnchor.constraint(equalTo: upcomingCard.trailingAnchor, constant: -pad),
            column.bottomAnchor.constraint(equalTo: upcomingCard.bottomAnchor, constant: -DesignSystem.Spacing.sm)
        ])
        contentStack.addArrangedSubview(upcomingCard)
    }

    private func configureCategoryCard() {
        categoryHeaderLabel.font = DesignSystem.Typography.sectionHeader
        categoryHeaderLabel.textColor = DesignSystem.Colors.textSecondary
        categoryHeaderLabel.adjustsFontForContentSizeCategory = true
        categoryHeaderLabel.text = Strings.Dashboard.byCategory

        legendStack.axis = .horizontal
        legendStack.spacing = DesignSystem.Spacing.md
        legendStack.alignment = .center

        let column = UIStackView(arrangedSubviews: [categoryHeaderLabel, categoryBar, legendStack])
        column.axis = .vertical
        column.spacing = DesignSystem.Spacing.md
        column.translatesAutoresizingMaskIntoConstraints = false

        categoryCard.translatesAutoresizingMaskIntoConstraints = false
        categoryCard.addSubview(column)
        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: categoryCard.topAnchor, constant: pad),
            column.leadingAnchor.constraint(equalTo: categoryCard.leadingAnchor, constant: pad),
            column.trailingAnchor.constraint(equalTo: categoryCard.trailingAnchor, constant: -pad),
            column.bottomAnchor.constraint(equalTo: categoryCard.bottomAnchor, constant: -pad)
        ])
        contentStack.addArrangedSubview(categoryCard)
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    // MARK: - Rendering

    private func render(_ state: ViewState<DashboardViewModel.Snapshot>) {
        switch state {
        case .idle, .loading:
            scrollView.isHidden = false
            emptyStateView.isHidden = true
            emptyView.isHidden = true
        case .loaded(let snapshot):
            scrollView.isHidden = false
            emptyStateView.isHidden = true
            emptyView.isHidden = true
            apply(snapshot)
        case .empty:
            scrollView.isHidden = true
            emptyStateView.isHidden = true
            emptyView.isHidden = false
        case .failed(let message):
            scrollView.isHidden = true
            emptyView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(with: .init(
                title: Strings.Common.somethingWentWrong,
                message: message,
                systemIcon: "exclamationmark.triangle"
            ))
        }
    }

    private func apply(_ snapshot: DashboardViewModel.Snapshot) {
        // Hero — primary currency total with dimmed decimals.
        if let primary = snapshot.totals.first {
            heroAmountLabel.setDimmedDecimals(primary.amountText, font: DesignSystem.Typography.heroAmount)
            heroAmountLabel.accessibilityLabel = "\(Strings.Dashboard.thisMonth), \(primary.amountText)"
        }
        applyCurrencyChips(snapshot.currencyChips)
        applyTrendChart(snapshot.trend)
        applyTrendLine(snapshot)
        applyUpcoming(snapshot.upcoming)
        applyCategories(snapshot.categories)
    }

    private func applyCurrencyChips(_ chips: [DashboardViewModel.CurrencyChip]) {
        currencyChipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currencyChipScroll.isHidden = chips.isEmpty
        for chip in chips {
            let button = FilterChipButton(title: chip.title, isSelected: chip.isSelected)
            button.onTap = { [weak self] in
                self?.haptics.play(.selection)
                self?.viewModel.selectCurrency(chip.currencyCode)
            }
            currencyChipStack.addArrangedSubview(button)
        }
    }

    private func applyTrendChart(_ trend: [DashboardViewModel.TrendMonth]) {
        miniChart.isHidden = trend.isEmpty
        guard !trend.isEmpty else { return }
        miniChart.configure(with: .init(
            bars: trend.map { .init(value: $0.normalized, label: $0.letter, isAccent: $0.isCurrent) },
            barWidth: 14,
            barRadius: 5,
            gap: 6,
            accessibilityLabel: Strings.Dashboard.thisMonth
        ))
    }

    /// "▾ 4% vs June · 6 active · $857/yr" — delta part tinted accent.
    private func applyTrendLine(_ snapshot: DashboardViewModel.Snapshot) {
        var parts: [String] = []
        if let delta = snapshot.deltaText { parts.append(delta) }
        parts.append(Strings.Dashboard.activeCount(snapshot.totalActiveCount))
        if let primary = snapshot.totals.first {
            parts.append(Strings.Dashboard.yearlyShort(primary.yearlyText))
        }
        let text = parts.joined(separator: " · ")
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: DesignSystem.Typography.footnote,
                .foregroundColor: DesignSystem.Colors.textSecondary
            ]
        )
        if let delta = snapshot.deltaText, let range = text.range(of: delta) {
            attributed.addAttribute(
                .foregroundColor,
                value: DesignSystem.Colors.accentText,
                range: NSRange(range, in: text)
            )
        }
        trendLabel.attributedText = attributed
    }

    private func applyUpcoming(_ rows: [DashboardViewModel.UpcomingRow]) {
        upcomingStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        upcomingCard.isHidden = rows.isEmpty
        for (index, row) in rows.prefix(3).enumerated() {
            if index > 0 { upcomingStack.addArrangedSubview(makeSeparator()) }
            upcomingStack.addArrangedSubview(makeUpcomingRow(row))
        }
    }

    private func makeUpcomingRow(_ row: DashboardViewModel.UpcomingRow) -> UIView {
        let tile = SublyAvatarView()
        tile.setSize(40)
        let brand = SublyBrandAppearance.appearance(forName: row.name, categoryName: nil)
        tile.configure(with: .init(initial: brand.initial, background: brand.background, foreground: brand.foreground))

        let nameLabel = UILabel()
        nameLabel.text = row.name
        nameLabel.font = DesignSystem.Typography.rowTitle
        nameLabel.textColor = DesignSystem.Colors.textPrimary
        nameLabel.adjustsFontForContentSizeCategory = true

        let metaLabel = UILabel()
        metaLabel.text = row.dateText
        metaLabel.font = DesignSystem.Typography.footnote
        metaLabel.textColor = row.isImminent
            ? DesignSystem.Colors.accentText
            : DesignSystem.Colors.textSecondary
        metaLabel.adjustsFontForContentSizeCategory = true

        let textColumn = UIStackView(arrangedSubviews: [nameLabel, metaLabel])
        textColumn.axis = .vertical
        textColumn.spacing = 1

        let priceLabel = SublyAmountLabel()
        priceLabel.emphasis = .primary
        priceLabel.text = row.amountText
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [tile, textColumn, UIView(), priceLabel])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = DesignSystem.Spacing.md
        rowStack.isLayoutMarginsRelativeArrangement = true
        rowStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: DesignSystem.Spacing.rowV, leading: 0,
            bottom: DesignSystem.Spacing.rowV, trailing: 0
        )

        let control = TapControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.isUserInteractionEnabled = false
        control.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: control.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: control.bottomAnchor)
        ])
        control.onTap = { [weak self] in
            self?.haptics.play(.selection)
            self?.viewModel.didSelectUpcoming(row.subscription)
        }
        control.isAccessibilityElement = true
        control.accessibilityTraits = .button
        control.accessibilityLabel = "\(row.name), \(row.amountText), \(row.dateText)"
        return control
    }

    private func applyCategories(_ segments: [DashboardViewModel.CategorySegment]) {
        categoryCard.isHidden = segments.isEmpty
        guard !segments.isEmpty else { return }
        categoryBar.configure(with: segments.map { .init(name: $0.name, fraction: $0.fraction) })

        legendStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, segment) in segments.enumerated() {
            legendStack.addArrangedSubview(makeLegendChip(segment, index: index))
        }
        legendStack.addArrangedSubview(UIView())
    }

    private func makeLegendChip(_ segment: DashboardViewModel.CategorySegment, index: Int) -> UIView {
        let dot = UIView()
        dot.backgroundColor = SublyCategoryBar.shade(at: index)
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8)
        ])

        let label = UILabel()
        label.text = segment.name
        label.font = DesignSystem.Typography.footnote
        label.textColor = DesignSystem.Colors.textSecondary
        label.adjustsFontForContentSizeCategory = true

        let chip = UIStackView(arrangedSubviews: [dot, label])
        chip.axis = .horizontal
        chip.alignment = .center
        chip.spacing = 5
        chip.isAccessibilityElement = true
        chip.accessibilityLabel = "\(segment.name), \(segment.totalText)"
        return chip
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = DesignSystem.Colors.hairline
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    // MARK: - Actions

    @objc private func didTapAvatar() {
        haptics.play(.selection)
        viewModel.didTapSettings()
    }

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter
    }()
}

/// Minimal tappable wrapper with a pressed-state dim, used for card rows.
private final class TapControl: UIControl {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(fire), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported.") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.65 : 1 }
    }

    @objc private func fire() { onTap?() }
}
