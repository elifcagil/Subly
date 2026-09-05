import UIKit

/// v5 Subscription Detail (screen 04): centered 72pt tile + name +
/// "Category · Cycle", accent hero card (Next renewal | Amount), "Paid so far"
/// card with payment-history bars, settings-style rows (Remind me, Notes),
/// and paired Archive / Delete pills.
final class SubscriptionDetailViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: SubscriptionDetailViewModel
    private let haptics: HapticsService

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!

    private let avatarView = SublyAvatarView()
    private let nameLabel = UILabel()
    private let categoryLineLabel = UILabel()

    private let heroCard = UIView()
    private let heroRenewalValue = UILabel()
    private let heroAmountValue = UILabel()

    private let paidCard = SublyCardView()
    private let paidTotalLabel = SublyAmountLabel()
    private let paidChart = SublyBarChart()
    private let paidCaptionLabel = UILabel()

    private let rowsCard = SublyCardView()
    private let reminderValueLabel = UILabel()
    private let notesValueLabel = UILabel()

    private let archiveButton = UIButton(type: .system)

    // MARK: - Init

    init(viewModel: SubscriptionDetailViewModel, haptics: HapticsService) {
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
        configureNavigationBar()
        configureContent()
        configureBindings()
        viewModel.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.reload()
    }

    // MARK: - Configuration

    private func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never
        let edit = UIBarButtonItem(
            title: Strings.Common.edit,
            style: .plain,
            target: self,
            action: #selector(didTapEdit)
        )
        edit.tintColor = DesignSystem.Colors.accentText
        navigationItem.rightBarButtonItem = edit
    }

    private func configureContent() {
        contentStack.spacing = DesignSystem.Spacing.section
        configureHeader()
        configureHeroCard()
        configurePaidCard()
        configureRowsCard()
        configureActions()
    }

    private func configureHeader() {
        avatarView.setSize(72)

        nameLabel.font = DesignSystem.Typography.title
        nameLabel.textColor = DesignSystem.Colors.textPrimary
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontForContentSizeCategory = true

        categoryLineLabel.font = DesignSystem.Typography.footnote
        categoryLineLabel.textColor = DesignSystem.Colors.textSecondary
        categoryLineLabel.textAlignment = .center
        categoryLineLabel.adjustsFontForContentSizeCategory = true

        let header = UIStackView(arrangedSubviews: [avatarView, nameLabel, categoryLineLabel])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = 3
        header.setCustomSpacing(DesignSystem.Spacing.md, after: avatarView)
        contentStack.addArrangedSubview(header)
    }

    /// Accent hero: "Next renewal / Tomorrow, July 4" | "Amount / $15.49",
    /// all content on the lime fill uses `accentOnFill`.
    private func configureHeroCard() {
        heroCard.backgroundColor = DesignSystem.Colors.accent
        heroCard.layer.cornerRadius = DesignSystem.Radius.card
        heroCard.layer.cornerCurve = .continuous

        let renewalTitle = heroCaption(Strings.SubscriptionDetail.nextRenewal)
        heroRenewalValue.font = DesignSystem.Typography.scaled(17, weight: .heavy, relativeTo: .body)
        heroRenewalValue.textColor = DesignSystem.Colors.accentOnFill
        heroRenewalValue.adjustsFontForContentSizeCategory = true
        heroRenewalValue.numberOfLines = 2

        let left = UIStackView(arrangedSubviews: [renewalTitle, heroRenewalValue])
        left.axis = .vertical
        left.spacing = 3

        let amountTitle = heroCaption(Strings.AddEdit.fieldAmount)
        heroAmountValue.font = DesignSystem.Typography.scaled(17, weight: .heavy, relativeTo: .body, tabular: true)
        heroAmountValue.textColor = DesignSystem.Colors.accentOnFill
        heroAmountValue.adjustsFontForContentSizeCategory = true
        heroAmountValue.textAlignment = .right

        let right = UIStackView(arrangedSubviews: [amountTitle, heroAmountValue])
        right.axis = .vertical
        right.alignment = .trailing
        right.spacing = 3

        let row = UIStackView(arrangedSubviews: [left, UIView(), right])
        row.axis = .horizontal
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(row)

        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: pad),
            row.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -pad),
            row.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -pad)
        ])
        heroCard.isAccessibilityElement = true
        contentStack.addArrangedSubview(heroCard)
    }

    private func heroCaption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DesignSystem.Typography.caption
        label.textColor = DesignSystem.Colors.accentOnFill.withAlphaComponent(0.65)
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func configurePaidCard() {
        let titleLabel = UILabel()
        titleLabel.text = Strings.SubscriptionDetail.paidSoFar
        titleLabel.font = DesignSystem.Typography.sectionHeader
        titleLabel.textColor = DesignSystem.Colors.textSecondary
        titleLabel.adjustsFontForContentSizeCategory = true

        paidTotalLabel.emphasis = .display

        paidChart.translatesAutoresizingMaskIntoConstraints = false
        paidChart.heightAnchor.constraint(equalToConstant: 44).isActive = true

        paidCaptionLabel.font = DesignSystem.Typography.footnote
        paidCaptionLabel.textColor = DesignSystem.Colors.textTertiary
        paidCaptionLabel.adjustsFontForContentSizeCategory = true
        paidCaptionLabel.numberOfLines = 0

        let column = UIStackView(arrangedSubviews: [titleLabel, paidTotalLabel, paidChart, paidCaptionLabel])
        column.axis = .vertical
        column.spacing = DesignSystem.Spacing.sm
        column.translatesAutoresizingMaskIntoConstraints = false

        paidCard.translatesAutoresizingMaskIntoConstraints = false
        paidCard.addSubview(column)
        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: paidCard.topAnchor, constant: pad),
            column.leadingAnchor.constraint(equalTo: paidCard.leadingAnchor, constant: pad),
            column.trailingAnchor.constraint(equalTo: paidCard.trailingAnchor, constant: -pad),
            column.bottomAnchor.constraint(equalTo: paidCard.bottomAnchor, constant: -pad)
        ])
        contentStack.addArrangedSubview(paidCard)
    }

    private func configureRowsCard() {
        reminderValueLabel.font = DesignSystem.Typography.body
        reminderValueLabel.textColor = DesignSystem.Colors.accentText
        reminderValueLabel.adjustsFontForContentSizeCategory = true

        notesValueLabel.font = DesignSystem.Typography.body
        notesValueLabel.textColor = DesignSystem.Colors.textSecondary
        notesValueLabel.adjustsFontForContentSizeCategory = true
        notesValueLabel.textAlignment = .right
        notesValueLabel.numberOfLines = 2

        let reminderRow = makeSettingsRow(
            title: Strings.SubscriptionDetail.remindMe,
            valueLabel: reminderValueLabel,
            showsChevron: true
        ) { [weak self] in
            self?.haptics.play(.selection)
            self?.viewModel.didTapReminder()
        }

        let notesRow = makeSettingsRow(
            title: Strings.AddEdit.fieldNotes,
            valueLabel: notesValueLabel,
            showsChevron: false,
            onTap: nil
        )

        let separator = UIView()
        separator.backgroundColor = DesignSystem.Colors.hairline
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let column = UIStackView(arrangedSubviews: [reminderRow, separator, notesRow])
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false

        rowsCard.translatesAutoresizingMaskIntoConstraints = false
        rowsCard.addSubview(column)
        let pad = DesignSystem.Spacing.cardPadding
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: rowsCard.topAnchor, constant: 4),
            column.leadingAnchor.constraint(equalTo: rowsCard.leadingAnchor, constant: pad),
            column.trailingAnchor.constraint(equalTo: rowsCard.trailingAnchor, constant: -pad),
            column.bottomAnchor.constraint(equalTo: rowsCard.bottomAnchor, constant: -4)
        ])
        contentStack.addArrangedSubview(rowsCard)
    }

    private func makeSettingsRow(
        title: String,
        valueLabel: UILabel,
        showsChevron: Bool,
        onTap: (() -> Void)?
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignSystem.Typography.rowTitle
        titleLabel.textColor = DesignSystem.Colors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true

        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        var views: [UIView] = [titleLabel, UIView(), valueLabel]
        if showsChevron {
            let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
            chevron.tintColor = DesignSystem.Colors.textTertiary
            chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            chevron.setContentHuggingPriority(.required, for: .horizontal)
            views.append(chevron)
        }

        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = DesignSystem.Spacing.sm
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)

        guard let onTap else {
            row.isAccessibilityElement = true
            row.accessibilityLabel = title
            return row
        }

        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        let control = DetailRowControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: control.topAnchor),
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: control.bottomAnchor),
            control.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        control.onTap = onTap
        control.isAccessibilityElement = true
        control.accessibilityLabel = title
        control.accessibilityTraits = .button
        return control
    }

    private func configureActions() {
        var archiveConfig = UIButton.Configuration.plain()
        archiveConfig.title = Strings.List.archiveAction
        archiveConfig.baseForegroundColor = DesignSystem.Colors.textPrimary
        archiveConfig.background.backgroundColor = DesignSystem.Colors.surface
        archiveConfig.background.strokeColor = DesignSystem.Colors.strokeControl
        archiveConfig.background.strokeWidth = 1
        archiveConfig.background.cornerRadius = 24
        archiveConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        archiveButton.configuration = archiveConfig
        archiveButton.titleLabel?.font = DesignSystem.Typography.rowTitle
        archiveButton.titleLabel?.adjustsFontForContentSizeCategory = true
        archiveButton.addTarget(self, action: #selector(didTapArchive), for: .touchUpInside)

        let deleteButton = UIButton(type: .system)
        var deleteConfig = UIButton.Configuration.plain()
        deleteConfig.title = Strings.Common.delete
        deleteConfig.baseForegroundColor = DesignSystem.Colors.danger
        deleteConfig.background.backgroundColor = DesignSystem.Colors.dangerTint
        deleteConfig.background.cornerRadius = 24
        deleteConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        deleteButton.configuration = deleteConfig
        deleteButton.titleLabel?.font = DesignSystem.Typography.rowTitle
        deleteButton.titleLabel?.adjustsFontForContentSizeCategory = true
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [archiveButton, deleteButton])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = DesignSystem.Spacing.cardGap
        contentStack.addArrangedSubview(row)
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onDeleteRequested = { [weak self] in
            self?.presentDeleteConfirmation()
        }
    }

    // MARK: - Rendering

    private func render(_ state: ViewState<SubscriptionDetailViewModel.Snapshot>) {
        switch state {
        case .idle, .loading, .empty:
            return
        case .loaded(let snapshot):
            apply(snapshot)
        case .failed(let message):
            present(errorMessage: message)
        }
    }

    private func apply(_ snapshot: SubscriptionDetailViewModel.Snapshot) {
        title = snapshot.title
        nameLabel.text = snapshot.title
        categoryLineLabel.text = snapshot.categoryLine
        categoryLineLabel.isHidden = snapshot.categoryLine.isEmpty

        let brand = SublyBrandAppearance.appearance(forName: snapshot.title, categoryName: nil)
        avatarView.configure(with: .init(initial: brand.initial, background: brand.background, foreground: brand.foreground))

        heroRenewalValue.text = snapshot.renewalText
        heroAmountValue.text = snapshot.amountText
        heroCard.accessibilityLabel =
            "\(Strings.SubscriptionDetail.nextRenewal), \(snapshot.renewalText). \(Strings.AddEdit.fieldAmount), \(snapshot.amountText)"

        if let paid = snapshot.paidSoFar {
            paidCard.isHidden = false
            paidTotalLabel.setDimmedDecimals(paid.totalText, font: DesignSystem.Typography.statAmount)
            paidCaptionLabel.text = paid.captionText
            paidChart.configure(with: .init(
                bars: paid.bars.enumerated().map { index, value in
                    .init(value: value, label: nil, isAccent: index == paid.bars.count - 1)
                },
                barWidth: 14,
                barRadius: 5,
                gap: 6,
                accessibilityLabel: paid.captionText
            ))
        } else {
            paidCard.isHidden = true
        }

        reminderValueLabel.text = snapshot.reminderValue
        notesValueLabel.text = snapshot.notes?.isEmpty == false ? snapshot.notes : "—"

        archiveButton.configuration?.title = snapshot.isArchived
            ? Strings.List.unarchiveAction
            : Strings.List.archiveAction
    }

    private func presentDeleteConfirmation() {
        presentDeleteSubscriptionPrompt(name: viewModel.subscription.name, haptics: haptics) { [weak self] in
            self?.viewModel.confirmDelete()
        }
    }

    private func present(errorMessage: String) {
        let alert = UIAlertController(title: nil, message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Strings.Common.ok, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func didTapEdit() {
        viewModel.didTapEdit()
    }

    @objc private func didTapArchive() {
        haptics.play(.lightImpact)
        viewModel.toggleArchive()
    }

    @objc private func didTapDelete() {
        viewModel.didTapDelete()
    }
}

private final class DetailRowControl: UIControl {
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
