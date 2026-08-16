import UIKit

final class FinancialLoadViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var emptyStateView: SublyEmptyStateView!

    // MARK: - Dependencies

    private let viewModel: FinancialLoadViewModel

    // MARK: - State

    /// One section view per currency, keyed by currency code so we can scroll
    /// to a specific one on initial load.
    private var sectionViewsByCurrency: [String: UIView] = [:]

    // MARK: - Init

    init(viewModel: FinancialLoadViewModel) {
        self.viewModel = viewModel
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(viewModel:).")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Strings.FinancialLoad.title
        view.backgroundColor = DesignSystem.Colors.background
        navigationItem.largeTitleDisplayMode = .never
        configureBindings()
        viewModel.start()
    }

    private func configureBindings() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onScrollToCurrencyRequested = { [weak self] code in
            self?.scrollToSection(currencyCode: code)
        }
    }

    // MARK: - Rendering

    private func render(_ state: ViewState<FinancialLoadViewModel.Snapshot>) {
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
                title: Strings.FinancialLoad.emptyTitle,
                message: Strings.FinancialLoad.emptyMessage,
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

    private func apply(_ snapshot: FinancialLoadViewModel.Snapshot) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        sectionViewsByCurrency.removeAll()

        for section in snapshot.sections {
            let view = makeSectionView(for: section)
            contentStack.addArrangedSubview(view)
            sectionViewsByCurrency[section.currencyCode] = view
        }
    }

    private func scrollToSection(currencyCode: String) {
        guard let target = sectionViewsByCurrency[currencyCode] else { return }
        view.layoutIfNeeded()
        let rectInScroll = scrollView.convert(target.bounds, from: target)
        scrollView.scrollRectToVisible(rectInScroll, animated: false)
    }

    // MARK: - Section / Card builders

    private func makeSectionView(for section: FinancialLoadViewModel.Section) -> UIView {
        let header = makeSectionHeader(currencyCode: section.currencyCode)

        let cards = section.cards.map(makeCard(for:))
        let cardsStack = UIStackView(arrangedSubviews: cards)
        cardsStack.axis = .vertical
        cardsStack.spacing = DesignSystem.Spacing.md
        cardsStack.alignment = .fill

        let stack = UIStackView(arrangedSubviews: [header, cardsStack])
        stack.axis = .vertical
        stack.spacing = DesignSystem.Spacing.sm
        stack.alignment = .fill
        return stack
    }

    private func makeSectionHeader(currencyCode: String) -> UIView {
        let label = UILabel()
        label.text = currencyCode
        label.font = DesignSystem.Typography.subhead
        label.textColor = DesignSystem.Colors.textSecondary
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func makeCard(for card: FinancialLoadViewModel.HorizonCard) -> UIView {
        let cardView = SublyCardView()
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = card.horizonTitle
        titleLabel.font = DesignSystem.Typography.subhead
        titleLabel.textColor = DesignSystem.Colors.textSecondary
        titleLabel.adjustsFontForContentSizeCategory = true

        let toneChip = SublyChip()
        toneChip.configure(with: .init(
            text: Strings.FinancialLoad.toneLabel(card.tone),
            systemIcon: nil,
            tone: chipTone(for: card.tone)
        ))
        toneChip.setContentHuggingPriority(.required, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [titleLabel, toneChip])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = DesignSystem.Spacing.md

        let amountLabel = UILabel()
        amountLabel.font = DesignSystem.Typography.amount
        amountLabel.textColor = DesignSystem.Colors.textPrimary
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.text = card.isEmpty ? (card.emptyText ?? "—") : card.totalText
        amountLabel.numberOfLines = 2

        let subtitleLabel = UILabel()
        subtitleLabel.font = DesignSystem.Typography.footnote
        subtitleLabel.textColor = DesignSystem.Colors.textSecondary
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.text = card.subtitleText
        subtitleLabel.isHidden = card.isEmpty

        var rows: [UIView] = [headerRow, amountLabel]
        if !card.isEmpty {
            rows.append(subtitleLabel)
        }
        if let peakText = card.peakText {
            let peakLabel = UILabel()
            peakLabel.font = DesignSystem.Typography.footnote
            peakLabel.textColor = DesignSystem.Colors.textTertiary
            peakLabel.adjustsFontForContentSizeCategory = true
            peakLabel.text = peakText
            peakLabel.numberOfLines = 0
            rows.append(peakLabel)
        }

        let contentStack = UIStackView(arrangedSubviews: rows)
        contentStack.axis = .vertical
        contentStack.spacing = DesignSystem.Spacing.xs
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: DesignSystem.Spacing.lg),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: DesignSystem.Spacing.lg),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DesignSystem.Spacing.lg),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -DesignSystem.Spacing.lg)
        ])

        cardView.isAccessibilityElement = true
        cardView.accessibilityLabel = "\(card.horizonTitle), \(card.totalText), \(card.subtitleText)"

        return cardView
    }

    /// Tone → chip mapping. Per §9.12, `.peak` does **not** map to `.danger`
    /// — Subly never uses red. Peak gets the same warning amber as heavy, but
    /// the surrounding copy carries the difference.
    private func chipTone(for tone: FinancialLoadWindow.Tone) -> SublyChip.Tone {
        switch tone {
        case .light: return .neutral
        case .moderate: return .accent
        case .heavy, .peak: return .warning
        }
    }
}
