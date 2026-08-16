import UIKit

/// v5 Timeline. Week mode (screen 06): "July" title + "$71.46 due", week
/// strip, day-grouped renewal cards. Month mode (screen 10): "July 2026" +
/// ‹ › paging, calendar grid card, "Payments this month" day-keyed list.
final class TimelineViewController: UIViewController {

    private let viewModel: TimelineViewModel
    private let haptics: HapticsService

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let emptyStateView = SublyEmptyStateView()

    // Week mode
    private let monthLabel = UILabel()
    private let dueLabel = UILabel()
    private let weekStrip = SublyWeekStrip()
    private let groupsStack = UIStackView()

    // Mode switch + month mode
    private let modePills = SublySegmentedPills()
    private let monthHeaderRow = UIStackView()
    private let monthYearLabel = UILabel()
    private let previousMonthButton = UIButton(type: .system)
    private let nextMonthButton = UIButton(type: .system)
    private let monthGridCard = SublyCardView()
    private let monthGrid = SublyMonthGrid()
    private let paymentsHeaderRow = UIStackView()
    private let paymentsTitleLabel = UILabel()
    private let paymentsTotalLabel = UILabel()
    private let paymentsStack = UIStackView()

    init(viewModel: TimelineViewModel, haptics: HapticsService) {
        self.viewModel = viewModel
        self.haptics = haptics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:haptics:).")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.Timeline.title
        view.backgroundColor = DesignSystem.Colors.background
        configureHierarchy()
        configureBindings()
        viewModel.start()
        if ProcessInfo.processInfo.arguments.contains("-previewMonth") {
            viewModel.setMode(.month)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // v5 timeline draws its own header; restore the bar for pushes.
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    private func configureHierarchy() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = DesignSystem.Spacing.section
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)

        let inset = DesignSystem.Spacing.screenH
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: inset),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -inset),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -inset * 2),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: inset)
        ])

        // Header: month + due amount.
        monthLabel.font = DesignSystem.Typography.largeTitle
        monthLabel.textColor = DesignSystem.Colors.textPrimary
        monthLabel.adjustsFontForContentSizeCategory = true

        dueLabel.font = DesignSystem.Typography.footnote
        dueLabel.adjustsFontForContentSizeCategory = true

        let header = UIStackView(arrangedSubviews: [monthLabel, dueLabel])
        header.axis = .vertical
        header.spacing = 2
        contentStack.addArrangedSubview(header)

        // Week / Month mode pills.
        modePills.configure(
            segments: [.init(title: Strings.Timeline.week), .init(title: Strings.Timeline.month)],
            selectedIndex: 0
        )
        modePills.onSelect = { [weak self] index in
            self?.haptics.play(.selection)
            self?.viewModel.setMode(index == 0 ? .week : .month)
        }
        contentStack.addArrangedSubview(modePills)

        contentStack.addArrangedSubview(weekStrip)

        groupsStack.axis = .vertical
        groupsStack.spacing = DesignSystem.Spacing.section
        contentStack.addArrangedSubview(groupsStack)

        configureMonthViews()
    }

    // MARK: Month overview (screen 10)

    private func configureMonthViews() {
        monthYearLabel.font = DesignSystem.Typography.sectionHeader
        monthYearLabel.textColor = DesignSystem.Colors.textPrimary
        monthYearLabel.textAlignment = .center
        monthYearLabel.adjustsFontForContentSizeCategory = true

        configurePagerButton(previousMonthButton, icon: "chevron.left", label: Strings.Timeline.previousMonth)
        previousMonthButton.addTarget(self, action: #selector(didTapPreviousMonth), for: .touchUpInside)
        configurePagerButton(nextMonthButton, icon: "chevron.right", label: Strings.Timeline.nextMonth)
        nextMonthButton.addTarget(self, action: #selector(didTapNextMonth), for: .touchUpInside)

        monthHeaderRow.axis = .horizontal
        monthHeaderRow.alignment = .center
        monthHeaderRow.spacing = DesignSystem.Spacing.md
        monthHeaderRow.addArrangedSubview(previousMonthButton)
        monthHeaderRow.addArrangedSubview(monthYearLabel)
        monthHeaderRow.addArrangedSubview(nextMonthButton)
        monthYearLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentStack.addArrangedSubview(monthHeaderRow)

        monthGrid.translatesAutoresizingMaskIntoConstraints = false
        monthGridCard.translatesAutoresizingMaskIntoConstraints = false
        monthGridCard.addSubview(monthGrid)
        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            monthGrid.topAnchor.constraint(equalTo: monthGridCard.topAnchor, constant: pad),
            monthGrid.leadingAnchor.constraint(equalTo: monthGridCard.leadingAnchor, constant: pad),
            monthGrid.trailingAnchor.constraint(equalTo: monthGridCard.trailingAnchor, constant: -pad),
            monthGrid.bottomAnchor.constraint(equalTo: monthGridCard.bottomAnchor, constant: -pad)
        ])
        contentStack.addArrangedSubview(monthGridCard)

        paymentsTitleLabel.text = Strings.Timeline.paymentsThisMonth
        paymentsTitleLabel.font = DesignSystem.Typography.sectionHeader
        paymentsTitleLabel.textColor = DesignSystem.Colors.textSecondary
        paymentsTitleLabel.adjustsFontForContentSizeCategory = true

        paymentsTotalLabel.font = DesignSystem.Typography.scaled(15, weight: .bold, relativeTo: .body, tabular: true)
        paymentsTotalLabel.textColor = DesignSystem.Colors.accentText
        paymentsTotalLabel.adjustsFontForContentSizeCategory = true
        paymentsTotalLabel.setContentHuggingPriority(.required, for: .horizontal)

        paymentsHeaderRow.axis = .horizontal
        paymentsHeaderRow.alignment = .firstBaseline
        paymentsHeaderRow.addArrangedSubview(paymentsTitleLabel)
        paymentsHeaderRow.addArrangedSubview(UIView())
        paymentsHeaderRow.addArrangedSubview(paymentsTotalLabel)
        contentStack.addArrangedSubview(paymentsHeaderRow)
        contentStack.setCustomSpacing(DesignSystem.Spacing.sm, after: paymentsHeaderRow)

        paymentsStack.axis = .vertical
        paymentsStack.spacing = DesignSystem.Spacing.md
        contentStack.addArrangedSubview(paymentsStack)
    }

    private func configurePagerButton(_ button: UIButton, icon: String, label: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        config.baseForegroundColor = DesignSystem.Colors.textSecondary
        config.background.backgroundColor = DesignSystem.Colors.surface
        config.background.strokeColor = DesignSystem.Colors.strokeControl
        config.background.strokeWidth = 1
        config.background.cornerRadius = 17
        button.configuration = config
        button.accessibilityLabel = label
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 34),
            button.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    // MARK: - Rendering

    private func render(_ state: ViewState<TimelineViewModel.Snapshot>) {
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
                title: Strings.Timeline.emptyTitle,
                message: Strings.Timeline.emptyMessage,
                systemIcon: "calendar"
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

    private func apply(_ snapshot: TimelineViewModel.Snapshot) {
        let isMonth = snapshot.mode == .month
        weekStrip.isHidden = isMonth
        groupsStack.isHidden = isMonth
        dueLabel.isHidden = isMonth || snapshot.dueAmountText == nil
        monthHeaderRow.isHidden = !isMonth
        monthGridCard.isHidden = !isMonth
        paymentsHeaderRow.isHidden = !isMonth
        paymentsStack.isHidden = !isMonth
        modePills.setSelectedIndex(isMonth ? 1 : 0)

        if isMonth {
            applyMonth(snapshot)
            return
        }

        monthLabel.text = snapshot.monthTitle

        if let due = snapshot.dueAmountText {
            let text = Strings.Timeline.due(due)
            let attributed = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: DesignSystem.Typography.footnote,
                    .foregroundColor: DesignSystem.Colors.textSecondary
                ]
            )
            if let range = text.range(of: due) {
                attributed.addAttributes([
                    .foregroundColor: DesignSystem.Colors.accentText,
                    .font: DesignSystem.Typography.scaled(13, weight: .bold, relativeTo: .footnote, tabular: true)
                ], range: NSRange(range, in: text))
            }
            dueLabel.attributedText = attributed
            dueLabel.isHidden = false
        } else {
            dueLabel.isHidden = true
        }

        weekStrip.configure(days: snapshot.week.map { day in
            .init(
                weekdayLetter: day.weekdayLetter,
                dayNumber: day.dayNumber,
                isToday: day.isToday,
                hasRenewal: day.renewalCount > 0,
                accessibilityLabel: "\(day.weekdayLetter) \(day.dayNumber)"
            )
        })

        groupsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for group in snapshot.groups {
            groupsStack.addArrangedSubview(makeGroupCard(group))
        }
    }

    private func applyMonth(_ snapshot: TimelineViewModel.Snapshot) {
        monthLabel.text = snapshot.monthTitle
        monthYearLabel.text = snapshot.monthYearTitle
        monthGrid.configure(
            weekdayLetters: snapshot.weekdayLetters,
            days: snapshot.gridDays.map { day in
                .init(
                    dayNumber: day.dayNumber,
                    isInMonth: day.isInMonth,
                    isToday: day.isToday,
                    hasRenewal: day.hasRenewal,
                    accessibilityLabel: day.isInMonth ? day.dayNumber : nil
                )
            }
        )

        paymentsTotalLabel.text = snapshot.monthTotalText
        paymentsTotalLabel.isHidden = snapshot.monthTotalText == nil

        paymentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for payments in snapshot.monthPayments {
            paymentsStack.addArrangedSubview(makeMonthPaymentsRow(payments))
        }
    }

    /// Day-keyed payments row: accent day number in a 34pt column + rows.
    private func makeMonthPaymentsRow(_ payments: TimelineViewModel.MonthPayments) -> UIView {
        let dayLabel = UILabel()
        dayLabel.text = payments.dayNumber
        dayLabel.font = DesignSystem.Typography.scaled(15, weight: .heavy, relativeTo: .body, tabular: true)
        dayLabel.textColor = DesignSystem.Colors.accentText
        dayLabel.textAlignment = .center
        dayLabel.adjustsFontForContentSizeCategory = true
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        dayLabel.widthAnchor.constraint(equalToConstant: 34).isActive = true
        dayLabel.setContentHuggingPriority(.required, for: .horizontal)

        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        for (index, row) in payments.rows.enumerated() {
            if index > 0 { rowsStack.addArrangedSubview(makeSeparator()) }
            rowsStack.addArrangedSubview(makeRenewalRow(row))
        }

        let card = SublyCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rowsStack)
        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 2),
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
            rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -2)
        ])

        let row = UIStackView(arrangedSubviews: [dayLabel, card])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = DesignSystem.Spacing.sm
        return row
    }

    // MARK: - Actions

    @objc private func didTapPreviousMonth() {
        haptics.play(.selection)
        viewModel.stepMonth(-1)
    }

    @objc private func didTapNextMonth() {
        haptics.play(.selection)
        viewModel.stepMonth(1)
    }

    private func makeGroupCard(_ group: TimelineViewModel.DayGroup) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = group.title
        titleLabel.font = DesignSystem.Typography.sectionHeader
        titleLabel.textColor = DesignSystem.Colors.textSecondary
        titleLabel.adjustsFontForContentSizeCategory = true

        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        for (index, row) in group.rows.enumerated() {
            if index > 0 { rowsStack.addArrangedSubview(makeSeparator()) }
            rowsStack.addArrangedSubview(makeRenewalRow(row))
        }

        let column = UIStackView(arrangedSubviews: [titleLabel, rowsStack])
        column.axis = .vertical
        column.spacing = DesignSystem.Spacing.sm
        column.translatesAutoresizingMaskIntoConstraints = false

        let card = SublyCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignSystem.Spacing.sm)
        ])
        return card
    }

    private func makeRenewalRow(_ row: TimelineViewModel.RenewalRow) -> UIView {
        let tile = SublyAvatarView()
        tile.setSize(40)
        let brand = SublyBrandAppearance.appearance(forName: row.name, categoryName: row.categoryName)
        tile.configure(with: .init(initial: brand.initial, background: brand.background, foreground: brand.foreground))

        let nameLabel = UILabel()
        nameLabel.text = row.name
        nameLabel.font = DesignSystem.Typography.rowTitle
        nameLabel.textColor = DesignSystem.Colors.textPrimary
        nameLabel.adjustsFontForContentSizeCategory = true

        let metaLabel = UILabel()
        metaLabel.text = row.categoryName
        metaLabel.font = DesignSystem.Typography.footnote
        metaLabel.textColor = DesignSystem.Colors.textSecondary
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.isHidden = row.categoryName == nil

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

        let control = TimelineRowControl()
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
            self?.viewModel.didSelect(row.subscription)
        }
        control.isAccessibilityElement = true
        control.accessibilityTraits = .button
        control.accessibilityLabel = "\(row.name), \(row.amountText)"
        return control
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = DesignSystem.Colors.hairline
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}

private final class TimelineRowControl: UIControl {
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
